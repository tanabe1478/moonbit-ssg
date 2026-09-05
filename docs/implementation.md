# 実装ガイド

MoonBitを学びながら内部実装を読むための資料です。利用方法はrootの`README.md`を参照してください。

## この段階で登場するMoonBit文法

```moonbit
pub fn version() -> String {
  "0.1.0"
}
```

- `fn`は関数を定義します。
- `pub`を付けると、別packageから呼び出せます。
- `-> String`は戻り値の型です。
- 最後の式が関数の戻り値になるため、`return`は不要です。

```moonbit
"moonbit-ssg \{version()}"
```

`\{...}`は文字列補間です。

```moonbit
println(@ssg.banner())
```

`@ssg`は`cmd/main/moon.pkg`で付けたpackage aliasです。libraryとCLIを分けることで、今後SSGの処理をtestしやすくします。

```moonbit
test "the public API exposes the CLI banner" {
  inspect(@moonbit_ssg.banner(), content="moonbit-ssg 0.1.0")
}
```

`_test.mbt`はblack-box testです。`inspect`は実際の値を期待する文字列と比較するsnapshot assertionです。

## Publish互換の入力parser

`src/source.mbt`の`parse_source`は、Markdownをfrontmatterと本文に分けます。

```moonbit
pub(all) struct SourceDocument {
  metadata : Metadata
  item : ItemMetadata
  markdown : String
}
```

- `struct`は複数のfieldを持つデータ型です。
- `pub(all)`にすると型だけでなくfieldも別packageへ公開されます。
- `String?`は値がない可能性を表し、`Some(value)`または`None`になります。
- `match`で`Some`と`None`を漏れなく処理します。
- `Array[String]`は可変長の文字列配列です。

frontmatterは一般的なYAMLではなく、Publishが内部で使うInkの挙動に合わせています。

- `key: value`形式
- `tags`はカンマ区切り
- 空のmetadata valueは無視
- `:`がない行は直前のvalueへ連結
- 同じkeyが複数あれば後のvalueを採用
- 閉じられていないfrontmatterは通常のMarkdownとして保持

この互換性は`tests/source_test.mbt`のblack-box testで固定しています。

## Ink互換のMarkdown renderer

`src/markdown.mbt`の`render_markdown`は、`mizchi/markdown`で構文木を作り、独自のserializerでInkと同じHTML形状へ変換します。

既製rendererをそのまま使わない理由は、CommonMarkとInkで次の出力が異なるためです。

- block要素間の改行有無
- `<img>`、`<hr>`、`<br>`などのtag表記
- 画像だけの段落
- 入れ子および空行を含むlist
- CRLFを含む旧記事の解釈
- YouTube blockquote modifier
- HighlightJS pluginが付与する`hljs-*` markup

```moonbit
match inline {
  @markdown.Inline::Text(content~, ..) => escape_html(content)
  @markdown.Inline::Strong(children~, ..) =>
    "<strong>\{render_inlines(children, definitions)}</strong>"
  // 他のInline variantも列挙
}
```

- `enum`は複数の形を取り得るdata型です。Markdown ASTの`Inline`や`Block`が該当します。
- `match`で各variantを分岐します。MoonBit compilerは分岐の不足を検査します。
- `children~`はnamed fieldを同名の変数へ取り出すpatternです。
- `..`はこの分岐では使わないfieldを省略します。
- blockとinlineを再帰的に描画することで、入れ子のlistやlink内の画像を扱います。
- `StringBuilder`はline endingの互換変換やsyntax highlightを1文字ずつ組み立てるために使います。

syntax highlightは、現行記事で使われているshellとSwiftを対象に、現在のHighlightJS出力と同じclassを生成します。新しい言語や構文を追加するときは、まずPublishの出力fixtureをtestへ追加してから互換範囲を広げます。

`tests/markdown_test.mbt`では通常のMarkdownに加え、CRLF、Ink固有のlist構造、YouTube埋め込み、shell/Swift highlightを固定しています。さらに現行記事すべての本文HTMLをPublish出力と比較し、一致を確認しています。

CLIで1記事の変換結果を確認できます。

```sh
mise exec -- moon run cmd/main -- render-markdown PATH_TO_POST.md
```

CLIはfrontmatterを除いた本文をrendererへ渡し、HTMLを標準出力へ書きます。

## Content directoryとsite model

`src/content.mbt`はPublish形式の`Content/index.md`、`Content/posts/index.md`、各記事を読み、後続のthemeやfeed生成から使う`SiteContent`へ変換します。

```moonbit
pub(all) struct Post {
  slug : String
  title : String
  description : String
  date : String
  tags : Array[String]
  body_html : String
} derive(Eq, Debug)
```

- `derive(Eq, Debug)`は、値の比較とtest向け表示の実装をcompilerに生成させます。
- `Post::path`のように`型名::method`で、その型に紐づくmethodを定義できます。
- `raise @fs.IOError`はfilesystem処理が失敗し得ることを関数の型に表します。
- file I/Oを行う`load_site_content`と、純粋にmodelを組み立てる`build_site_content`を分け、並び順などを小さなtestで確認できるようにしています。

記事titleはfrontmatter、最初のlevel-one heading、file名の順にfallbackします。記事一覧用の日付降順、tag抽出とtag別記事抽出もこの層で提供します。section pageだけはPublishの現行挙動に合わせ、file名順の元配列を使います。

## Publish互換theme

`src/theme.mbt`は`SiteConfig`と`SiteContent`から、次のHTMLを文字列として生成します。

- site index
- posts section
- post detail
- tag list
- tag detail

先に純粋な`String` rendererとして実装し、directory作成やfile書き込みは次の層へ分離しています。これにより、head metadata、記事順、Google Analyticsの挿入範囲などをfilesystemなしでtestできます。

```moonbit
pub fn render_post_page(config : SiteConfig, post : Post) -> String
```

`SiteConfig`にはsite URL、名前、説明、favicon、stylesheet、feed、profile linkなど、Swift側の`Website`とthemeに埋め込まれていた値を集約しています。

互換性のため、通常なら変更したくなる次の挙動も現行出力に合わせています。

- indexとtagは日付降順、sectionは元のfile名順
- Google Analytics nodeはcustom headを使うindex・section・tag pageだけに挿入
- tag detailのcanonical URLではUnicode pathをUTF-8 percent encoding
- 空文字ではなく文字列`""`のdescriptionは、そのままmeta tagと一覧へ出力

現行siteのindex、section、tag list、tag detail、代表postをbyte単位で比較し、すべてPublish出力との一致を確認しています。

## Outputの生成

`src/output.mbt`の`write_site_output`は、出力directoryをcleanにしてからHTMLを書き、`Resources`を再帰的にcopyします。themeが指定するstylesheetは、Publishと同様にrootの`styles.css`へもcopyします。

```sh
mise exec -- moon run cmd/main -- build Content Resources Output.moonbit
```

引数は順番にContent directory、Resources directory、出力directoryです。現在のCLIのsite設定は、移行対象ブログのSwift `Blog`とthemeの値を明示的に移したものです。将来別siteで使う設定形式を追加するときも、library APIの`SiteConfig`はそのまま利用できます。

filesystem処理では次の再帰関数を分けています。

- `ensure_directory`: 親directoryから順番に作成
- `remove_tree`: 古い出力を子から削除
- `copy_tree`: binaryを含むResourcesをbyteのままcopy
- `write_output_file`: HTMLの親directoryを作って書き込み

## RSSとsitemap

`src/feed.mbt`はPublishとPlotの既定設定に合わせてRSS 2.0とsitemap XMLを生成します。

- RSSは記事を日付降順にして最大100件出力
- RSS内のroot-relative URLはsiteのabsolute URLへ変換
- 記事日時はreference buildと同じUTC offsetのRFC 822形式
- sitemapはposts sectionと全記事を出力
- RSSのbuild日時とsitemapの`lastmod`は同じ`BuildDate`を利用

通常のbuildではJSTの現在時刻を使います。比較時は任意のbuild日時を`yyyy-MM-ddTHH:mm:ss+HHMM`でCLIの最後へ渡せます。offsetを省略した場合は`+0900`です。時刻を値として注入する設計にしたため、testは現在時刻に依存せず決定的です。

```moonbit
pub fn write_site_output(
  config : SiteConfig,
  content_directory : String,
  resources_directory : String,
  output_directory : String,
  theme_stylesheet? : String = "MyHtmlTheme/styles.css",
  build_date? : BuildDate,
) -> Unit raise @fs.IOError
```

- `引数? : T`は省略可能なoptional引数です。
- 呼び出し側で`build_date?`と書くと、`T?`をoptional引数へそのまま転送できます。
- build日時を省略した場合だけ`current_build_date`を評価します。

現行siteを固定build日時で実際に生成し、Publishの`Output`と比較した結果、全生成ファイルがbyte単位で一致しています。

