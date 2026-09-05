# 実装guide

[English](implementation.md)

MoonBitを学びながら内部実装を読むための資料です。目的別の手順は[使い方](usage.ja.md)から読んでください。

## 公開関数とpackage

```moonbit
pub fn version() -> String {
  "0.1.0"
}
```

- `fn`は関数を定義します。
- `pub`を付けると別packageから呼び出せます。
- `-> String`は戻り値の型です。
- 最後の式が戻り値になるため、明示的な`return`は不要です。

文字列補間には`\{...}`を使います。

```moonbit
"moonbit-ssg \{version()}"
```

alias付きでimportしたpackageは`@alias`から呼び出します。

```moonbit
println(@ssg.banner())
```

CLIはlibraryを`@ssg`としてimportします。packageを分けることで、command line解析を通さず再利用APIをtestできます。

## Black-box test

`_test.mbt`で終わるfileにtestを書きます。`tests` packageは外部利用者と同じように`src`をimportします。

```moonbit
test "the public API exposes the CLI banner" {
  inspect(@ssg.banner(), content="moonbit-ssg 0.1.0")
}
```

`inspect`は値をsnapshot文字列と比較します。`Debug`をderiveしたarray、enum、struct、`Result`には`debug_inspect`が便利です。

## Publish互換source parser

`src/source.mbt`はMarkdownをfrontmatterと本文に分けます。

```moonbit
pub(all) struct SourceDocument {
  metadata : Metadata
  item : ItemMetadata
  markdown : String
}
```

- `struct`は名前付きfieldを持つ積型です。
- `pub(all)`は型とfieldを公開します。
- `String?`は`Some(value)`または`None`で表すoptional値です。
- `match`はenum variantを網羅的に処理します。
- `Array[String]`は可変長の文字列配列です。

一般的なYAML parserではなく、Ink/Publishの挙動を意図的に再現します。

- `key: value`形式
- comma区切りtag
- 空metadata valueを無視
- `:`がない行を直前valueへ連結
- 重複keyは最後を採用
- 閉じられていないfrontmatterは通常Markdownとして保持

`tests/source_test.mbt`のblack-box testで挙動を固定しています。

## Ink互換Markdown rendering

`src/markdown.mbt`は`mizchi/markdown`でASTを作り、Ink互換ruleを持つserializerでHTMLへ変換します。

既定CommonMark rendererだけでは、次のInkとの差を再現できません。

- block要素間の改行
- `<img>`、`<hr>`、`<br>`の表記
- 画像だけの段落
- nested listと空行で分離されたlist
- 旧記事のCRLF入力
- YouTube blockquote modifier
- HighlightJSの`hljs-*` markup

AST variantを`match`で分岐します。

```moonbit
match inline {
  @markdown.Inline::Text(content~, ..) => escape_html(content)
  @markdown.Inline::Strong(children~, ..) =>
    "<strong>\{render_inlines(children, definitions)}</strong>"
}
```

- `enum`は複数variantのいずれかを表します。
- `match`の網羅性はcompilerが検査します。
- `content~`はnamed fieldを同名変数へ束縛します。
- `..`は不要なfieldを無視します。
- blockとinlineの再帰renderでnested listやlink内画像を処理します。

syntax highlightは移行blog fixtureに必要なshellとSwiftのmarkupを再現します。言語追加時は先にfixtureを追加します。

CLIから直接確認できます。

```sh
mise exec -- moon run cmd/main -- render-markdown PATH_TO_POST.md
```

## Content読込

`src/publish_content.mbt`の汎用loaderは次に対応します。

- 複数section
- root・nested free-form page
- nested item path
- `.md`、`.markdown`、`.txt`、`.text`
- custom metadata
- path・RSS override
- audio、video、podcast metadata

```moonbit
let content = @ssg.load_published_content("Content", ["posts", "episodes"])
```

I/Oと純粋なmodel構築を分けています。`build_published_content`は文字列から同じmodelを作るため、sorting、metadata、mutationをfilesystemなしでtestできます。

`src/content.mbt`の`SiteContent`は歴史的blog adapterです。新しい再利用codeでは`PublishedContent`を使います。

## HTML factoryとtheme

`PublishHTMLFactory`はindex、section、item、page、tag list、tag detailのcallbackを保持します。`generate_publish_html`は`PublishedContent`のlocationを出力pathへ対応させ、callbackを呼びます。

2つのoutput modeがあります。

- `FoldersAndIndexFiles`: `/posts/hello/index.html`
- `StandAloneFiles`: `/posts/hello.html`

組み込みFoundation実装:

- `foundation_html_factory`
- `default_foundation_theme_configuration`
- `foundation_stylesheet`
- `write_foundation_stylesheet`

blog固有rendererは`src/theme.mbt`へ分離し、歴史的なbyte出力を維持しつつ、新規projectのdefaultへ不自然な挙動を持ち込みません。

## Feedとsitemap

汎用feedは`src/publish_feed.mbt`と`src/podcast.mbt`へ分けています。

`render_publish_rss_feed`はsection選択、item predicate、最大件数、TTL、target path、GUID/link override、title/body prefix・suffixに対応します。

`render_publish_podcast_feed`はaudio URL、duration、byte sizeを検証し、author、owner、category、episode、season、explicit、enclosure、media contentを含むApple Podcasts / Media RSS metadataを生成します。

両feedにcached版があります。指定timezoneを維持しつつbuild時刻を固定してcache keyを作ります。build時刻だけは無効化条件から除き、contentと設定はkeyへ含めます。

`render_publish_sitemap`はsection、item、page、excluded path、`lastModified`集約に対応します。

`BuildDate`は注入できます。

```moonbit
let date = @ssg.BuildDate::parse("2026-09-05T13:44:37+0900").unwrap()
```

通常buildは現在時刻を使いつつ、testを決定的にできます。

## Filesystem出力

出力処理を4つに分けています。

- `ensure_directory`: 親から順番にdirectoryを作成
- `remove_tree`: 子から古い出力を削除
- recursive copy helper: binary resourceとpathを維持
- `write_output_file`: 親directoryを作ってfile書込

`write_site_output`はblog互換writerです。汎用projectの`build_publish_project`は`load_published_content`、HTML生成、Foundation resource、cached RSS、sitemap生成を合成します。

## 永続cache形式

`cached_publish_value`と`cached_publish_result`は`.publish/Caches`以下へ保存します。entryは長さprefix付きのcaller-defined keyとcache valueで構成します。改行を含むkey/valueを扱いつつJSON dependencyを増やさない形式です。

`Result`版はproducer成功後だけ書き込みます。壊れたcache entryはmissとして扱います。

## Immutable content操作

Publishのthrowing/inout操作は、更新済みcontentを返すimmutableなMoonBit関数へ置き換えます。

- item・page追加
- 条件一致item削除
- 1 item、全item、pageのmutation
- 指定sectionのsort
- predicateのinverse、AND、OR合成

失敗は`Result`で返し、呼び出し側が更新結果を受理しない限り以前の値を維持します。

## Publishing pipeline

`PublishingStep`はname、kind、context変換を持ちます。

```moonbit
type operation =
  (PublishingContext) -> Result[PublishingContext, String]
```

empty、group、conditional、optional、custom、plugin install、generation、deployment stepがあります。deploymentは`deploy` flagで明示的にgateします。

`PublishingContext`は新しい値として返します。Swift Publishのthrowing `inout`操作に対するMoonBit版であり、Swift source API互換ではありません。

## Git deployment

libraryの組み込みGit helperはshell文字列を実行せず、注入runnerへ次の値を渡します。

```moonbit
pub(all) struct DeploymentCommand {
  working_directory : String
  executable : String
  arguments : Array[String]
}
```

永続repositoryを初期化し、`origin`設定、初回pull失敗許容、branch checkout/作成、`.git`を維持したoutput同期、add/commit/pushを行います。

CLIはMoonBit async process APIを具体的なhost runnerとして使います。認証は外部へ委ねます。

## 汎用project CLI

`src/project.mbt`は`site.md`解析、website/plugin package scaffold、汎用build合成を担当します。`cmd/main`は引数を解析し、errorを表示してlibrary APIを呼ぶ薄い層です。

`new plugin`は既存MoonBit module内へpackageを生成します。MoonBit module manifestはregistry外Git dependencyを直接参照できないため、standalone dependencyは生成しません。

## Blog互換adapter

低level command:

```sh
mise exec -- moon run cmd/main -- build Content Resources Output
```

は歴史的な`tanabe1478/blog`設定とtheme contractを使います。移行済み本番siteを安定させるためのadapterです。新規siteでは`site.md`、`new`、`generate`を使ってください。
