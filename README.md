# moonbit-ssg

Swift Publish 0.9互換を目標にした、MoonBit製の静的サイトジェネレーターです。

現在は`tanabe1478/blog`が使用する生成機能を移行済みで、Swift Publishの出力と全ファイルがbyte単位で一致しています。Publishの汎用機能についても段階的に互換範囲を広げています。

## 必要な環境

MoonBit toolchainは[mise](https://mise.jdx.dev/)で管理しています。

```sh
mise install
```

`mise.toml`はMoonBit `0.10.11+6ff76a5f9`を固定し、公式archiveと標準libraryのSHA-256を検証します。

## CLIの使い方

helpを表示します。

```sh
mise exec -- moon run cmd/main
```

Foundation themeを使う新しいsite projectを作成し、生成します。

```sh
mise exec -- moon run cmd/main -- new my-site "My Site"
mise exec -- moon run cmd/main -- generate my-site
mise exec -- moon run cmd/main -- run my-site -p 8000
```

`run`はsiteを再生成してからPython標準HTTP serverを起動します。生成された`site.md`でURL、site名、section、tag path、output directoryを設定できます。`.publish/Caches`はstep単位の永続cacheで、変更のないfeedを再利用します。libraryからは`render_cached_publish_rss_feed`と`render_cached_publish_podcast_feed`を利用できます。

Git remoteへdeployする場合は`site.md`のfrontmatterへ設定を追加します。

```yaml
deploymentRemote: git@github.com:owner/site.git
deploymentBranch: pages
deploymentDirectory: .publish/Git
deploymentCommitMessage: Publish deploy
```

```sh
mise exec -- moon run cmd/main -- deploy my-site
```

tokenは`site.md`やremote URLへ書かず、SSH agentまたはGit credential managerで管理してください。

既存のMoonBit moduleへplugin packageを追加する場合:

```sh
mise exec -- moon run cmd/main -- \
  new plugin path/to/image_optimizer "Image Optimizer"
```

生成されるpackageは、親moduleの`moon.mod`が`tanabe1478/moonbit-ssg`へ依存していることを前提にします。moduleや架空のregistry dependencyは自動生成しません。

Markdown本文をPublish互換HTMLへ変換します。

```sh
mise exec -- moon run cmd/main -- render-markdown PATH_TO_POST.md
```

移行検証用に`tanabe1478/blog`互換のsiteを直接生成する場合:

```sh
mise exec -- moon run cmd/main -- build Content Resources Output
```

再現可能な比較buildでは、最後にbuild日時とUTC offsetを指定します。offsetを省略すると`+0900`です。

```sh
mise exec -- moon run cmd/main -- \
  build Content Resources Output 2026-09-05T13:44:37+0900
```

## Libraryとして使う

利用側packageの`moon.pkg`からlibrary packageをimportします。

```moonbit
import {
  "tanabe1478/moonbit-ssg/src" @ssg,
}
```

例:

```moonbit
let document = @ssg.parse_source(markdown)
let html = @ssg.render_markdown(document.markdown)
```

複数section・free-form pageを含むPublish形式の`Content` directoryも読み込めます。

```moonbit
let content = @ssg.load_published_content("Content", ["posts", "episodes"])
```

公開APIの詳細は`src/pkg.generated.mbti`で確認できます。

## 開発

format、型検査、全testを実行します。

```sh
mise run check
```

個別のMoonBit commandを使う場合:

```sh
mise exec -- moon fmt
mise exec -- moon check
mise exec -- moon test
mise exec -- moon info
```

## Directory構成

```text
.
├── src/                 # 再利用可能なlibrary package
├── tests/               # libraryのblack-box test package
├── cmd/main/            # CLI executable package
├── docs/                # 設計・内部実装・互換範囲
├── moon.mod             # module metadataと依存
├── mise.toml            # toolchain固定と開発task
└── README.md            # 導入と利用方法
```

MoonBitでは`moon.pkg`を置いたdirectoryがpackage境界です。`src`内の機能は相互依存が強いため一つのlibrary packageにし、CLIとtestだけを別packageに分離しています。

## Documentation

- [`docs/architecture.md`](docs/architecture.md) — package構成と設計方針
- [`docs/implementation.md`](docs/implementation.md) — parserやrendererの内部実装
- [`docs/compatibility.md`](docs/compatibility.md) — Publish 0.9との互換範囲

## License

MIT
