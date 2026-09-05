# Architecture

[English](architecture.md)

## Moduleとpackage

MoonBitでは`moon.mod`を持つrepository全体がmodule、`moon.pkg`を持つdirectoryがpackage境界です。

このrepositoryは責務ごとに3 packageへ分けています。

```text
tanabe1478/moonbit-ssg/src       library
tanabe1478/moonbit-ssg/tests     black-box tests
tanabe1478/moonbit-ssg/cmd/main  CLI
```

`src`内をさらにdirectory分割しないのは意図的です。parser、content model、theme、feed、output、cache、pipelineは型と内部helperを共有します。現時点で分割するとpackage間依存が複雑になり、循環依存を作る可能性があります。十分に独立し、公開APIを安定させられる段階でsubpackageへ分離します。

## Libraryの層

```text
source.mbt
  frontmatterとraw metadata
      │
      ├── markdown.mbt
      │     Ink互換HTML変換
      │
      ├── content.mbt / publish_content.mbt
      │     blog固有 / Publish汎用content model
      │
      ├── theme.mbt / publish_html.mbt / foundation.mbt
      │     blog固有theme / callback HTML factory / Foundation theme
      │
      ├── feed.mbt / publish_feed.mbt / podcast.mbt
      │     blog固有・汎用RSS、sitemap、podcast feed
      │
      ├── output.mbt / publish_files.mbt / project.mbt
      │     filesystem出力、resource copy、汎用project
      │
      ├── pipeline.mbt / deployment.mbt
      │     immutable publishing stepとdeployment helper
      │
      └── cache.mbt
            step単位の永続cache
```

純粋な文字列・model変換とfilesystem I/Oを分け、前者の大部分をfilesystem fixtureなしでtestできるようにしています。

## Content model

2つの層を意図的に共存させています。

- `SiteContent`と`SiteConfig`は`tanabe1478/blog`の歴史的な出力contractを正確に維持します。
- `PublishedContent`と`PublishSiteConfig`は、複数section、page、nested item path、custom metadata、media、feed、factory、pipelineといった再利用可能なPublish相当機能を提供します。

新しい汎用機能は`PublishedContent`層へ追加します。blog固有挙動は分離し、互換修正が新規siteのdefaultへ漏れないようにします。

## Immutable pipeline

`PublishingContext`はsite設定、公開content、project root、output pathを保持します。`PublishingStep`はcontextを受け取り、`inout`変更や型のない例外の代わりに`Result[PublishingContext, String]`を返します。

generationとdeployment stepは同じ形です。deployment stepはpipeline実行時に明示的にdeployを有効にした場合だけ動きます。group、conditional、optional、plugin、content操作、file copy、runner注入式deploymentを同じcontext変換として合成できます。

## 永続cache

cacheは次へ保存します。

```text
.publish/Caches/<step>/<name>
```

cache keyは呼び出し側が決めます。keyが一致した場合、producerは呼ばれません。汎用projectのfeedでは、build時刻を固定したrender結果をkeyにします。これによりsite設定、item数、本文、RSS metadata、timezoneの変更では無効化し、build時刻だけの変更では再利用します。

RSSとpodcast rendererにはcached版があります。不正なpodcast metadataはerrorを返し、既存cacheを書き換えません。

## Processとcredentialの境界

libraryは補間したshell文字列を実行しません。Git/GitHub deployment helperはworking directory、executable、argument配列を持つ`DeploymentCommand`を作り、host注入のrunnerが実行します。process policyとcredentialをlibraryの外に保つ設計です。

CLIは`run`と`deploy`のhostになります。

- `run`はMoonBit async process APIからPython HTTP serverを起動します。
- `deploy`はargument配列でGitを実行し、library APIで`.git`を維持しながらoutputを同期します。

secretはproject metadataへ保存せず、SSH agent、credential manager、CI secret storageから渡します。

## Test package

`tests`は`src`をimportする独立packageなので、原則として公開APIだけを利用します。

- `*_test.mbt`: 機能別black-box test
- `test_fs.mbt`: filesystem fixture helper
- `moon.pkg`: test専用package import

private実装ではなく利用者から見える振る舞いを固定し、内部refactorでfixtureを書き換えずに済む構成を優先します。

## CLI package

`cmd/main`は引数解釈、利用者向けerror、host process実行を担当します。scaffold、project読込、生成、output同期、renderingはCLI分岐へ埋め込まず、libraryの公開APIへ置きます。

低levelの`build` commandだけは`tanabe1478/blog`用の明示的な互換adapterとして残します。新規projectは`site.md`と汎用`generate` commandを利用します。
