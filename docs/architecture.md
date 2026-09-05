# Architecture

## Moduleとpackage

MoonBitでは`moon.mod`を持つrepository全体がmodule、`moon.pkg`を持つdirectoryがpackageです。

このrepositoryは責務ごとに3 packageへ分けています。

```text
tanabe1478/moonbit-ssg/src       library
tanabe1478/moonbit-ssg/tests     black-box tests
tanabe1478/moonbit-ssg/cmd/main  CLI
```

`src`内をさらにdirectory分割しないのは、directoryを単なる整理用folderとして扱えず、すべて別packageになるためです。parser、content model、theme、feed、outputは型と内部helperを共有するので、現時点では一つのlibrary packageにまとめています。独立性が高くなった機能は、循環依存を作らず公開APIを安定させられる段階でsubpackageへ分離します。

## Libraryの層

```text
source.mbt
  frontmatterとraw metadata
      │
      ├── markdown.mbt
      │     Ink互換HTML変換
      │
      ├── content.mbt / publish_content.mbt
      │     blog固有model / Publish汎用model
      │
      ├── theme.mbt / publish_html.mbt
      │     blog固有theme / callback式HTMLFactory
      │
      ├── feed.mbt / publish_feed.mbt
      │     blog固有 / Publish汎用RSSとsitemap
      │
      ├── output.mbt / project.mbt
      │     filesystem出力 / 汎用project生成
      │
      └── cache.mbt
            step単位の永続cache
```

純粋な文字列・model変換とfilesystem I/Oを分け、前者を小さくtestできるようにしています。

永続cacheは`.publish/Caches/<step>/<name>`へ保存します。cache keyの決定は呼び出し側へ委ね、同じkeyならproducerを呼ばず値を再利用します。汎用project buildでは、build時刻を固定してrenderしたRSSをkeyにすることで、site設定・item数・本文・RSS metadata・timezone offsetの変更を検出します。

## Test package

`tests`は`src`をimportする独立packageです。これにより、testは原則として公開APIだけを利用します。

- `*_test.mbt`: 機能別のblack-box test
- `test_fs.mbt`: filesystem fixture用のtest helper
- `moon.pkg`: testで必要なlibraryとfilesystem依存

private実装の形ではなく利用者から見える振る舞いを固定するため、内部refactorを行ってもtestを変更しなくて済む構成を優先しています。

## CLI package

`cmd/main`は引数の解釈とerror表示を担当します。`new`のscaffold、`generate`の汎用project build、ブログ互換buildはいずれも`src`の公開APIを呼び出し、生成処理をCLI固有コードへ埋め込みません。`run`と`deploy`だけはhost processの起動が必要なため、CLI packageからargument配列としてPythonまたはGitを実行します。Git checkoutへのoutput同期はlibrary APIへ分離しています。
