# CentralSearch

Central Repositoryを検索するツールです。

## インストール

```
$ curl -O https://github.com/magnolia-k/central_search/releases/download/0.2.0/centralsearch-0.2.0.gem
$ gem install centralsearch-0.2.0.gem
```

## 使い方

### キーワード検索

引数に一つだけキーワードを渡すと、キーワード検索になります。

```
$ centralsearch scala-dist
org.scala-lang              scala-dist  2.12.1(28)  2016-12-05 20:10:23 +0900
org.typelevel               scala-dist  2.12.0(4)   2016-11-02 21:23:38 +0900
....
```

groupidか、artifactidの部分一致でcentral repositoryを検索して、結果を表示します。
groupid, artifactid, 最新バージョン(括弧内は最新バージョン), 更新日時の順に表示されます。

デフォルトでは、group idか、artifact idのどちらかで検索しますが、
オプションに`-g`でgroup idのみ、`-a`でartifact idのみを対象に検索します。

この場合は部分一致ではなく、完全一致での検索になります。

### group idと、artifact idによる検索

引数に二つのキーワードを渡すと、順にgroup id、artifact idと解釈して検索し、
バージョンの一覧を表示します。

```
$ centralsearch org.scala-lang scala-dist
org.scala-lang  scala-dist  2.11.8-18269ea      2017-01-06 06:03:42 +0900
org.scala-lang  scala-dist  2.12.1              2016-12-05 20:10:23 +0900
....
```

完全一致での検索になります。

`-f`オプションでバージョンの形式を正規表現で指定することができます。

```
$ centralsearch org.scala-lang scala-dist -f '^\d+\.\d+\.\d+$'
```

JVM系のライブラリでは、開発中のバージョンでは、バージョン番号の後ろに
日付等が付くので、それらを取り除くときに使います。

#### pecoと組み合わせ

キーワード検索では、検索結果が大量になるときが有り、group idと、artifact idを
コピペするのは面倒です。

そんなときは、pecoとの組み合わせが便利です。

``` 
$ centralsearch scala | peco | centralsearch
```

選択した行のgroup idと、artifact idで再検索され、バージョンの一覧が表示されます。

### metaデータの表示

group id, artifact id, バージョン番号を指定すると、metaデータを表示します。

```
$ bundle exec exe/centralsearch org.scala-lang scala-dist 2.12.0
  groupID: org.scala-lang
  artifactID: scala-dist
  version: 2.12.0
  description: The Artifacts Distributed with Scala
  organization: LAMP/EPFL
  url: http://www.scala-lang.org/
  scm: https://github.com/scala/scala.git
```

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

