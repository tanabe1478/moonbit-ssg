# 汎用SSG roadmap

[English](roadmap.md)

この文書では、moonbit-ssgを一般的なcontent中心の静的site generatorと比較し、Swift Publish互換の次に実装する機能へ優先度を付けます。

対象は実用的なblog・documentation用SSGです。JavaScript application frameworkになることや、比較対象すべての機能を再実装することは目標にしません。

## 互換性方針

互換性の境界はrepository構成やAPIの維持ではなく、生成結果です。HTML、公開URL、feed、sitemap entry、resource、browserから見える挙動は、意図した変更でない限り同等に保ちます。1.0以前は、重複を除いて汎用設計を改善できるなら、library API、`site.md`、CLI引数、内部model、blog repositoryを変更できます。

本番blogへ影響する変更は、同じ作業の流れで`tanabe1478/blog`側も更新し、生成結果とpublic smoke checkを確認します。site固有adapterは移行用であり、永続的なarchitecture制約にはしません。

## 比較対象

成熟したSSGの公式documentを参照しました。

- [Hugo content management](https://gohugo.io/content-management/)、[templates](https://gohugo.io/templates/)、[Hugo Pipes](https://gohugo.io/hugo-pipes/introduction/)
- [Jekyll documentation](https://jekyllrb.com/docs/)、[pagination](https://jekyllrb.com/docs/pagination/)
- [Eleventy documentation](https://www.11ty.dev/docs/)、[pagination](https://www.11ty.dev/docs/pagination/)
- [Zola content](https://www.getzola.org/documentation/content/overview/)、[templates](https://www.getzola.org/documentation/templates/overview/)
- [Astro content collections](https://docs.astro.build/en/guides/content-collections/)

各projectの対象範囲は異なります。複数の成熟したgeneratorが直接提供するか、標準的なecosystem機能として扱うものを一般的な機能とみなします。

## 現在の強み

moonbit-ssgは単純なMarkdown-to-HTML tool以上の土台を持っています。

- 固定された再現可能なMoonBit開発環境
- Publish/Ink互換Markdownとfrontmatter
- 複数section、nested item、free-form page
- path overrideと2つのHTML file mode
- tagとtag page
- callback式HTML factory
- 組み込みFoundation theme
- RSS、podcast feed、sitemap
- feed cache
- media componentとYouTube embed
- immutable content操作と合成可能predicate
- publishing stepとplugin
- resource copy
- argument配列境界を持つGit/GitHub deployment helper
- project scaffold、generate、preview server、deploy CLI
- 本番blogで検証済みの分離された互換adapter

## Gap matrix

Status:

- **実装済み**: 公開APIまたは汎用CLIから通常利用できる。
- **一部実装**: custom MoonBit codeが必要、用途が限定的、または標準的な使いやすさが不足する。
- **未実装**: 対応する実装がない。

| 機能 | 現状 | 成熟したSSGで一般的な挙動 | 優先度 |
| --- | --- | --- | --- |
| Markdown contentとfrontmatter | 実装済み。ただし意図的に完全YAMLではない | YAML/TOML/JSONまたは構造化data | P1 |
| 複数section/collectionとnested page | 実装済み | 標準機能 | 維持 |
| draft・未来・期限切れ制御 | 未実装 | 安全な公開filterと明示的override | **P0** |
| source位置付きcontent/schema検証 | 一部実装 | file/fieldを示すerror、schema | **P0** |
| file-based layoutとpartial | 一部実装。callback APIと組み込みthemeのみ | project内layout、継承、include/partial | **P0** |
| pagination | 未実装 | page分割、navigation metadata、安定URL | **P0** |
| watch modeとlive reload | 一部実装。1回生成後にserver起動 | 配信しながら変更を再生成 | **P0** |
| taxonomy | tagのみ | categoryとcustom taxonomy | P1 |
| permalink、alias、redirect | path overrideのみ | aliasとredirect page生成 | P1 |
| 404・robots.txt生成 | 未実装 | 設定可能な標準site file | P1 |
| syntax highlight | shell/Swift互換markupのみ | 多言語と設定可能theme | P1 |
| shortcode/component | YouTubeとlibrary media componentのみ | project固有拡張 | P1 |
| data file | 未実装 | JSON/YAML/TOML/CSVをtemplateから利用 | P1 |
| 画像処理 | 未実装 | resize、crop、responsive variant、metadata | P1 |
| asset pipeline | 再帰copyのみ | fingerprint、minify、Sass/CSS/JS処理 | P2 |
| incremental generation | feed cacheのみ | 未変更pageのrenderを省略 | template後にP1 |
| multilingual site | language metadataのみ | localized content tree、URL、fallback、feed | P2 |
| search index出力 | 未実装 | optional JSON/index生成 | P2 |
| 複数custom output format | library callbackで一部可能 | content typeごとのHTML/JSON/XML | P2 |
| remote content/data | 未実装 | optional fetch/build integration | P3 |
| Git deployment | 実装済み | pluginまたはhosting integrationが多い | 維持・将来分離検討 |
| podcast feed/media model | 実装済み | 最小SSG coreより多機能 | 維持・将来分離検討 |

## 優先度

### P0 — 汎用利用で先に必要

#### 1. 公開制御とvalidation

汎用content metadataとbuild policyへ次を追加します。

- `draft: true`
- 未来日付content
- `expiryDate`
- local preview・CI用の明示的include flag
- source pathと不正fieldを含むerror

最優先の理由: 下書きの誤公開と、原因が分からないbuild失敗は便利機能ではなく正しさの問題です。

出力条件: 公開制御によって現在公開中のblog contentを意図せず消してはいけません。意図的な未来日付記事はblog側の設定やmetadataを更新して許可できます。adapter API自体を維持する必要はありません。

#### 2. Project local layoutとpartial

callback factoryはMoonBit開発者には強力ですが、content作成者がproject内のHTMLを編集できません。小さく意図を限定したfile-based template layerを追加します。

- index、section、item、page、taxonomy layout
- 再利用可能partial
- defaultでescapeする補間
- 明示的raw HTML出力
- navigation/listに必要なloopとconditional
- 不足変数を示す明確なerror

実装前にdesign noteとprototypeを作ります。適切なMoonBit libraryがあるなら、大きな独自template言語を作るより依存を採用します。

#### 3. Pagination

templateと結合する前に純粋なpagination modelを作ります。

- page size設定
- first/subsequent pageの安定path
- total pageとitem range
- previous/next URL
- section・taxonomy pagination
- HTML paginationと独立したfeed動作

#### 4. 実用的なdevelopment watch mode

現在の`run`は「1回生成してserver起動」です。次へ拡張します。

- `site.md`、`Content`、`Resources`、project templateを監視
- 変更debounce
- 同時書込を避けた安全なrebuild
- error後も最後に成功したoutputを配信
- changed pathと解決可能なdiagnosticを表示
- browser reloadは後からoptional追加

live reloadより、まず信頼できるrebuildを優先します。

### P1 — blog/documentationで広く期待される

- custom taxonomyとcollection
- aliasとredirect page
- 設定可能な`404.html`と`robots.txt`
- templateから利用できるdata file
- 拡張可能shortcode/component
- 維持されているlibraryによる多言語syntax highlight
- image resizeとresponsive image metadata
- template依存が決まった後のpage単位incremental cache
- URL collisionと重複outputの厳密な検出

### P2 — 需要を確認して実装

- multilingual content treeとlocalized feed
- CSS/JS minifyとcontent fingerprint
- Sass等のpreprocessor integration
- search index生成
- content typeごとの複数output format
- theme packageとdiscovery

### P3 — 意図的に延期

- coreからのremote CMS/data fetch
- JavaScript bundlingやapplication island
- 完全なdevelopment web framework
- cloud provider固有deploy API

具体的なMoonBit use caseがない限り、pluginまたは外部build toolが適しています。

## Coreとして過剰な可能性がある機能

「過剰」は今すぐ削除する意味ではありません。便利でtest済みですが、最小の汎用SSG coreには必須でない機能です。

1. **`tanabe1478/blog` byte互換adapter** — 移行実績として有用ですが、site固有の一時的な層です。汎用設定/themeで公開結果を再現できたら削除します。
2. **Podcast・rich media** — 最小coreでは一般的でない。
3. **Git/GitHub deployment実装** — CI/pluginへ任せるSSGも多い。
4. **手書きshell/Swift highlight互換** — 対象が狭く移行由来。
5. **Ink固有の歴史的挙動** — 互換には必要だが新規siteのdefaultには不自然。

当面の方針:

- 置き換え経路を用意する間は生成結果を安定させる。
- blogを汎用APIへ移行した後、site固有APIを削除する。
- 互換挙動を汎用defaultへ漏らさない。
- 境界をdocument化する。
- MoonBit package依存をacyclicに保ち、公開APIが成熟した段階だけsubpackage化を検討する。

## 推奨実装順

1. **Build policy modelとdiagnostic**
2. **draft/future/expiry filter**
3. **純粋なpagination model**
4. **template engine調査とdesign note**
5. **project local layout/partial prototype**
6. **`tanabe1478/blog`を汎用設定へ移行し、専用adapterを削除**
7. **watch/rebuild loop**
8. **alias、404、robots、collision check**
9. **taxonomyとdata file**
10. **highlightとimage pipeline判断**
11. **page単位incremental cache**

純粋modelをI/Oより先に作り、template依存が決まる前にincremental cacheを作らない順序です。

## 最初の実装単位

最初は公開制御を実装します。reviewしやすい大きさで、実利用者を保護する効果が高いためです。

API/model案:

- raw metadataは維持する。
- blog固有modelを変えず、解析済みpublication stateを追加する。
- build日時と`include_drafts`、`include_future`、`include_expired`を持つ`PublishBuildPolicy`を定義する。
- HTML、tag、RSS、podcast、sitemap生成前に1回だけcontentをfilterする。
- `site.md` defaultとCLI overrideの両方から同じpolicyを使う。

受入条件:

1. `draft: true`はdefaultで除外する。
2. 未来記事は注入された`BuildDate`とtimezoneを基準にdefaultで除外する。
3. 期限切れcontentはdefaultで除外する。
4. preview flagで各categoryを独立して含められる。
5. 除外itemはsection、tag、RSS、podcast、sitemapのすべてに出ない。
6. 不正dateはsource pathとfieldを含むerrorを返す。
7. blog側の設定やmetadataは変更してよいが、意図した公開contentは維持する。
8. 既存汎用挙動の変更をpre-1.0の安全性修正としてdocument化する。

## 大きな実装前に決めること

- template syntaxとdependency
- layoutをinterpretするかcompiled MoonBitにするか
- pagination URL default
- filesystem watcher dependencyと対応platform
- syntax highlight libraryと出力安定性
- image library、対応format、native/Wasm portability
- optional機能を`src`へ残すかsubpackageへ分けるか

各判断はcode追加前に小さなdesign documentへ残します。
