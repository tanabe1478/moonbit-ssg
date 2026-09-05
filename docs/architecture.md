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
      ├── feed.mbt
      │     RSSとsitemap
      │
      └── output.mbt
            filesystem出力とresource copy
```

純粋な文字列・model変換とfilesystem I/Oを分け、前者を小さくtestできるようにしています。

## Test package

`tests`は`src`をimportする独立packageです。これにより、testは原則として公開APIだけを利用します。

- `*_test.mbt`: 機能別のblack-box test
- `test_fs.mbt`: filesystem fixture用のtest helper
- `moon.pkg`: testで必要なlibraryとfilesystem依存

private実装の形ではなく利用者から見える振る舞いを固定するため、内部refactorを行ってもtestを変更しなくて済む構成を優先しています。

## CLI package

`cmd/main`は引数の解釈とerror表示だけを担当します。生成処理は`src`の公開APIを呼び出し、CLI固有の処理へ埋め込みません。
