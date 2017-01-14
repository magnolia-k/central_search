require 'optparse'
require 'open-uri'
require 'rubygems'
require 'json'

require 'rexml/document'

class CentralSearch
  VERSION = '0.1.1'

  def initialize( argv )
    parse_options( argv )
  end

  def run
    if @cmd == nil then
      while str = STDIN.gets
        break if str != ""
      end
      args = str.split(/\s+/)

      if args.length < 2 then
        @groupid = args[0]
        @cmd = :cmd_search_by_keyword
      else 
        @groupid = args[0]
        @artifactid = args[1]
        @cmd = :cmd_search_by_g_and_a
      end
    end

    case @cmd
    when :cmd_help
      cmd_help
    when :cmd_version
      cmd_version
    when :cmd_search_by_keyword
      cmd_search_by_keyword
    when :cmd_search_by_g_and_a
      cmd_search_g_and_a
    when :cmd_display_pom_entry
      cmd_display_pom_entry
    end
  end

  private
  def cmd_help
    puts "usage: centralsearch [--version] [--help]"
    puts "                     <keyword> [-a][-g]"
    puts "                     <groupid> <artifactid>"
  end

  def cmd_version
    puts "centralsearch version #{VERSION}"
  end

  def cmd_search_by_keyword
    if @param[:keyword].match(/[^a-zA-Z0-9._\-]/) then
      raise "error: invalid search keyword #{param[:keyword]}"
    end

    query_param = ""

    if @param[:g] == false and @param[:a] == false then
      query_param = %!#{@param[:keyword]}&!
    elsif @param[:g] == true then
      query_param = %!g:"#{@param[:keyword]}"&!
    elsif @param[:a] == true then
      query_param = %!a:"#{@param[:keyword]}"&!
    end

    results = query_via_api( query_param ) do |item|
      version = item['latestVersion'] + "(" + item['versionCount'].to_s + ")"
      {
        :g => item['g'],
        :a => item['a'],
        :latest_version => item['latestVersion'],
        :timestamp => item['timestamp'] / 1000,
        :version_count => item['versionCount'],
        :display_version => item['latestVersion'] + "(" + item['versionCount'].to_s + ")"
      }
    end

    return if results.length == 0

    groupid_max_length    = results.map { |i| i[:g] }.max_by { |g| g.length }.length
    artifactid_max_length = results.map { |i| i[:a] }.max_by { |a| a.length }.length
    version_max_length    = results.map { |i| i[:display_version] }.max_by { |v| v.length }.length

    results.each do |result|
      groupid_padding    = groupid_max_length + 2 - result[:g].length
      artifactid_padding = artifactid_max_length + 2 - result[:a].length
      version_padding    = version_max_length + 2 - result[:display_version].length
      puts result[:g] + " " * groupid_padding + result[:a] + " " * artifactid_padding +
        result[:display_version] + " " * version_padding +
        Time.at( result[:timestamp].to_i ).to_s
    end
  end

  def cmd_search_g_and_a
    if @groupid.match(/[^a-zA-Z0-9._\-]/) then
      raise "error: invalid group id: #{@groupid}"
    end

    if @artifactid.match(/[^a-zA-Z0-9._\-]/) then
      raise "error: invalid artifact id: #{@artifactid}"
    end

    query_param = %!g:"#{@groupid}"+AND+a:"#{@artifactid}"&core=gav&!

    results = query_via_api( query_param ) do |item|
      {
        :g => item['g'],
        :a => item['a'],
        :timestamp => item['timestamp'] / 1000,
        :v => item['v']
      }
    end

    if @versionform != nil then
      results.select! do |result|
        result[:v].match( @versionform )
      end
    end

    return if results.length == 0

    groupid_max_length    = results.map { |i| i[:g] }.max_by { |g| g.length }.length
    artifactid_max_length = results.map { |i| i[:a] }.max_by { |a| a.length }.length
    version_max_length    = results.map { |i| i[:v] }.max_by { |v| v.length }.length

    results.each do |result|
      groupid_padding    = groupid_max_length + 2 - result[:g].length
      artifactid_padding = artifactid_max_length + 2 - result[:a].length
      version_padding    = version_max_length + 2 - result[:v].length
      puts result[:g] + " " * groupid_padding + result[:a] + " " * artifactid_padding +
        result[:v] + " " * version_padding + Time.at( result[:timestamp].to_i ).to_s
    end
  end

  def query_via_api(param)
    url = %!http://search.maven.org/solrsearch/select?q=! + param + %!rows=100&wt=json!

    start = 0
    is_finished = false
    docs = []

    begin
      open( url + "&start=#{start}" ) do |res|
        result = JSON.parse res.read

        if result["response"]["numFound"] == 0 then
          return [] # returns empty array
        end

        result["response"]["docs"].each do |doc|
          docs.push yield(doc)
        end

        if docs.length < result["response"]["numFound"] then
          start = docs.length
        else
          is_finished = true
        end
      end
    end while is_finished == false

    return docs
  end

  def cmd_display_pom_entry
    url = "http://search.maven.org/remotecontent?filepath="
    groupid = @groupid.gsub(/\./, '/')
    
    param = groupid + "/" + @artifactid + "/" + @version + "/" + @artifactid + "-" + @version +
      ".pom"

    begin
      open( url + param ) do |res|
        doc = REXML::Document.new( res )

        if doc.root == nil then
          raise "error: can't read pom.xml."
        end

        puts "  groupID: " + doc.elements['project/groupId'].text
        puts "  artifactID: " + doc.elements['project/artifactId'].text
        puts "  version: " + doc.elements['project/version'].text
        puts "  description: " + doc.elements['project/description'].text

        if doc.elements['project/organization/name'] != nil then
          puts "  organization: " + doc.elements['project/organization/name'].text
        end

        if doc.elements['project/url'] != nil then
          puts "  url: " + doc.elements['project/url'].text
        end

        if doc.elements['project/scm/url'] != nil then
          puts "  scm: " + doc.elements['project/scm/url'].text
        end

      end
    rescue OpenURI::HTTPError => e
      raise "error: invalid param: #{@groupid}, #{@artifactid}, #{@version}"
    end
  end

  def parse_options( argv )
    @cmd = nil

    @param        = { :keyword => nil, :a => false, :g => false }
    @artifactid   = nil
    @groupid      = nil
    @version      = nil

    @updated      = nil
    @versionform  = nil
    @maxnumber    = 20

    parser = OptionParser.new

    parser.on( '-h', '--help' ) do
      @cmd = :cmd_help
    end

    parser.on( '-v', '--version' ) do
      @cmd = :cmd_version
    end

    parser.on( '-n', '--maxnumber=NUM' ) do |num|
      if num.to_i == 0 then
        raise "error: invalid maxnumber option: #{num}"
      end

      @maxnumber = num.to_i
    end

    parser.on( '-u', '--updated=YEAR' ) do |year|
      if year.to_i then
        raise "error: invalid updated option: #{year}"
      end

      @updated = year.to_i
    end

    parser.on( '-f', '--versionform=PATTERN' ) do |pattern|
      begin
        @versionform = Regexp.compile(pattern)
      rescue RegexpError
        raise "error: invalid versionform option: #{pattern}"
      end
    end

    parser.on( '-a', '--artifactid' ) do
      @param[:a] = true
    end

    parser.on( '-g', '--groupid' ) do
      @param[:g] = true
    end

    parser.parse!( argv )

    if @cmd == nil then
      case argv.length
      when 0
#        @cmd = :cmd_help
      when 1
        @param[:keyword] = argv.shift

        @cmd = :cmd_search_by_keyword
      when 2
        @groupid = argv.shift
        @artifactid = argv.shift

        @cmd = :cmd_search_by_g_and_a
      else
        @groupid = argv.shift
        @artifactid = argv.shift
        version = argv.shift

        if version.match(/\)$/) then
          @cmd = :cmd_search_by_g_and_a
        else
          @version = version

          @cmd = :cmd_display_pom_entry
        end
      end
    end
  end
end
