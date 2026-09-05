# moonbit-ssg

[English](README.md)

Swift Publish 0.9と互換性のある出力・機能を目標にした、MoonBit製の静的site generatorです。

`tanabe1478/blog`は現在、moonbit-ssgだけで本番siteを生成しています。Swift Publishを削除する前に、88個の生成fileについてbyte単位の一致を確認し、desktop/mobileのbrowser表示でもpixel差分がないことを確認しました。

## 必要な環境

MoonBit toolchainは[mise](https://mise.jdx.dev/)で管理しています。

```sh
mise install
```

`mise.toml`はMoonBit `0.10.11+6ff76a5f9`を固定し、公式toolchainと標準library archiveのSHA-256を検証します。

`run`にはPython 3も必要です。Git deployの認証情報はSSH agentまたはGit credential managerから渡してください。

## Quick start

```sh
git clone https://github.com/tanabe1478/moonbit-ssg.git
cd moonbit-ssg
mise install

mise exec -- moon run cmd/main -- new my-site "My Site"
mise exec -- moon run cmd/main -- generate my-site
mise exec -- moon run cmd/main -- run my-site -p 8000
```

生成されるwebsiteでは、`site.md`が設定、`Content/`がMarkdown、`Resources/`が静的file、`Output/`が生成結果です。

project設定、content構成、deploy、plugin、library APIについては[使い方](docs/usage.ja.md)を参照してください。

## CLI概要

```text
new [website] [DIRECTORY] [NAME]  Foundation website projectを作成
new plugin [DIRECTORY] [NAME]     module内にplugin packageを作成
generate [ROOT] [BUILD_DATE]      汎用projectを生成
run [ROOT] [-p PORT]              汎用projectを生成して配信
deploy [ROOT]                     汎用projectを生成してdeploy
render-markdown INPUT             Markdown fileを1つ描画
build CONTENT RESOURCES OUTPUT [BUILD_DATE]
                                  tanabe1478/blog互換siteを生成
```

引数なしでhelpを表示します。

```sh
mise exec -- moon run cmd/main
```

## Libraryとして使う

利用側packageの`moon.pkg`からlibrary packageをimportします。

```moonbit
import {
  "tanabe1478/moonbit-ssg/src" @ssg,
}
```

公開parser・rendererの利用例です。

```moonbit
let document = @ssg.parse_source(markdown)
let html = @ssg.render_markdown(document.markdown)
let content = @ssg.load_published_content("Content", ["posts", "episodes"])
```

公開API全体は[`src/pkg.generated.mbti`](src/pkg.generated.mbti)で確認できます。

## 開発

format確認、型検査、全testを実行します。

```sh
mise run check
```

個別command:

```sh
mise exec -- moon fmt
mise exec -- moon check
mise exec -- moon test
mise exec -- moon info
```

## Repository構成

```text
.
├── src/                 # 再利用可能なlibrary package
├── tests/               # libraryのblack-box test
├── cmd/main/            # CLI executable package
├── docs/                # 使い方・設計・実装・互換範囲
├── resources/           # 組み込みFoundation theme resource
├── moon.mod             # module metadataと依存
├── mise.toml            # toolchain固定と開発task
└── README.md            # 英語の入口
```

MoonBitでは`moon.pkg`を置いたdirectoryがpackage境界です。相互依存が強いSSG componentは`src` packageへまとめ、CLIとblack-box testだけを別packageにしています。

## Documentation

- 使い方: [English](docs/usage.md) / [日本語](docs/usage.ja.md)
- Architecture: [English](docs/architecture.md) / [日本語](docs/architecture.ja.md)
- 実装guide: [English](docs/implementation.md) / [日本語](docs/implementation.ja.md)
- Publish 0.9互換範囲: [English](docs/compatibility.md) / [日本語](docs/compatibility.ja.md)

## License

MIT
