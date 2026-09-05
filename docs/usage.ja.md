# 使い方

[English](usage.md)

このguideでは、汎用project CLIと再利用可能なMoonBit libraryを説明します。内部設計は[Architecture](architecture.ja.md)と[実装guide](implementation.ja.md)を参照してください。

## 1. Repositoryを準備する

```sh
git clone https://github.com/tanabe1478/moonbit-ssg.git
cd moonbit-ssg
mise install
mise run check
```

以下の例では、このcheckoutからCLIを実行します。

```sh
mise exec -- moon run cmd/main -- COMMAND
```

## 2. Websiteを作成する

```sh
mise exec -- moon run cmd/main -- new my-site "My Site"
```

Publish風にkindを明示する形式も利用できます。

```sh
mise exec -- moon run cmd/main -- new website my-site "My Site"
```

`new`は空でないdirectoryを上書きしません。次のfileを生成します。

```text
my-site/
├── .gitignore
├── site.md
├── Content/
│   ├── index.md
│   └── posts/
│       ├── index.md
│       └── first-post.md
└── Resources/
```

## 3. `site.md`を設定する

`site.md`はPublish互換frontmatterを使います。

```yaml
---
url: https://example.com
name: My Site
description: Notes about MoonBit
language: ja
sections: posts
favicon: images/favicon.png
tagPath: tags
output: Output
---
```

| Key | 必須 | 既定値 | 意味 |
| --- | --- | --- | --- |
| `url` | yes | — | 公開siteのabsolute URL |
| `name` | yes | — | siteとfeedのtitle |
| `description` | no | 空 | siteとfeedの説明 |
| `language` | no | `en` | HTMLとfeedの言語 |
| `sections` | yes | — | comma区切りのsection directory名 |
| `image` | no | なし | 既定social image path |
| `favicon` | no | なし | favicon path |
| `tagPath` | no | `tags` | tag pageのbase path。`none`でtag HTMLを無効化 |
| `output` | no | `Output` | 生成先directory |

汎用CLIは組み込みFoundation themeを使い、`styles.css`、`feed.rss`、`sitemap.xml`も生成します。

## 4. Contentを追加する

`sections`に書いたsectionは、`Content`直下のdirectoryへ対応します。

```text
Content/
├── index.md
├── about.md
├── posts/
│   ├── index.md
│   ├── hello.md
│   └── guides/
│       └── setup.markdown
└── notes/
    └── now.md
```

- `Content/index.md`はsite indexです。
- `posts`など指定済みsectionにはsection pageとitem pageを生成します。
- root Markdownとsectionでないdirectory以下のfileはfree-form pageになります。
- section内のnested itemはnested pathを維持します。
- `.md`、`.markdown`、`.txt`、`.text`を読み込めます。

一般的なitem frontmatter:

```markdown
---
date: 2026-09-05 13:44
description: A short summary.
tags: moonbit, ssg
---
# Hello

Article body.
```

`title`、`date`、`lastModified`、`description`、`tags`、`path`、`image`、RSS override、audio/video、podcast metadataに対応しています。実装済み機能は[Publish互換範囲](compatibility.ja.md)を参照してください。

## 5. 生成・previewする

```sh
mise exec -- moon run cmd/main -- generate my-site
```

再現可能な出力にはbuild日時を渡します。

```sh
mise exec -- moon run cmd/main -- \
  generate my-site 2026-09-05T13:44:37+0900
```

形式は`yyyy-MM-ddTHH:mm:ss`で、`+HHMM` offsetは省略可能です。省略時は`+0900`です。

生成後にPythonのlocal HTTP serverを起動する場合:

```sh
mise exec -- moon run cmd/main -- run my-site
mise exec -- moon run cmd/main -- run my-site --port 4173
```

既定portは`8000`です。`CTRL-C`で停止します。

## 6. Feed cache

永続cacheは次に保存します。

```text
.publish/Caches/<step>/<name>
```

汎用buildでは、site設定、content、RSS metadata、timezoneが変わらなければRSS feedを再利用します。build時刻だけの変更では以前のfeedを維持し、Publishのfeed cacheと同じ挙動にします。

Libraryから利用するAPI:

```moonbit
@ssg.render_cached_publish_rss_feed(...)
@ssg.render_cached_publish_podcast_feed(...)
@ssg.cached_publish_value(...)
@ssg.cached_publish_result(...)
```

## 7. Gitでdeployする

`site.md`へdeploy設定を追加します。

```yaml
deploymentRemote: git@github.com:owner/site.git
deploymentBranch: pages
deploymentDirectory: .publish/Git
deploymentCommitMessage: Publish deploy
```

実行:

```sh
mise exec -- moon run cmd/main -- deploy my-site
```

このcommandは次を行います。

1. siteを生成する。
2. 永続deployment checkoutを初期化または再利用する。
3. `origin`を更新し、設定branchのpullを試みる。
4. branchをcheckoutし、存在しなければ作成する。
5. `.git`を維持して生成結果でcheckout内を置き換える。
6. add、commit、pushする。

commandはshell文字列ではなく、executableとargument配列として実行します。

`site.md`やremote URLへtokenを書かないでください。SSH agentまたはGit credential managerを利用します。CI secretはCI providerのsecret storageへ保存してください。

## 8. Plugin packageを作成する

`tanabe1478/moonbit-ssg`へ依存するMoonBit module内で実行します。

```sh
mise exec -- moon run cmd/main -- \
  new plugin path/to/image_optimizer "Image Optimizer"
```

`moon.pkg`と`plugin.mbt`を生成します。親moduleはmodule dependencyを宣言する責任を持ちます。未公開registry dependencyは自動生成しません。

生成pluginは`PublishPlugin`を返し、immutableな`PublishingContext`を受け取ります。

```moonbit
pub fn image_optimizer() -> @ssg.PublishPlugin {
  @ssg.publish_plugin("Image Optimizer", fn(context) {
    Ok(context)
  })
}
```

## 9. Markdown fileを1つ描画する

```sh
mise exec -- moon run cmd/main -- render-markdown Content/posts/hello.md
```

frontmatterを除き、Ink互換挙動で本文を描画してHTMLを標準出力へ書きます。

## 10. Libraryを利用する

`moon.pkg`へpackage importを宣言します。

```moonbit
import {
  "tanabe1478/moonbit-ssg/src" @ssg,
}
```

Publish形式のdirectory全体を読み込みます。

```moonbit
let content = @ssg.load_published_content(
  "Content",
  ["posts", "episodes"],
)
```

Foundation factoryでHTMLを生成します。

```moonbit
let site : @ssg.PublishSiteConfig = {
  url: "https://example.com",
  name: "Example",
  description: "Example site",
  language: "ja",
  image_path: None,
  favicon_path: Some("images/favicon.png"),
}

@ssg.generate_publish_html(
  "Output",
  content,
  @ssg.foundation_html_factory(site),
)
```

custom HTML factory、predicate、immutable content操作、publishing pipeline、feed/sitemap renderer、media component、file copy step、runner注入式Git/GitHub deploy helperも公開しています。正確なsignatureは[`src/pkg.generated.mbti`](../src/pkg.generated.mbti)を参照してください。

## 11. tanabe1478/blog互換siteを生成する

低levelの`build` commandは、移行元blog固有の出力contractを維持します。

```sh
mise exec -- moon run cmd/main -- \
  build Content Resources Output
```

再現可能な移行検証には日時を指定できます。

```sh
mise exec -- moon run cmd/main -- \
  build Content Resources Output 2026-09-05T13:44:37+0900
```

新規siteでは`new`、`site.md`、`generate`を利用してください。
