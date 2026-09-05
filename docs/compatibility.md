# Publish 0.9 compatibility

比較対象はSwift Publish `0.9.0`（revision `1c8ad00d39c985cb5d497153241a2f1b654e0d40`）です。

「ブログ移行に必要な互換性」と「Publish framework全体の汎用機能」は分けて管理します。

## tanabe1478/blogで使用している機能

以下は移行済みです。

- Ink互換frontmatter
- Markdown HTML変換
- YouTube modifier
- shell / Swift syntax highlight
- index、posts section、item、tag list、tag details
- custom theme metadata、canonical URL、OGP、Analytics
- Resourcesとtheme stylesheetのcopy
- RSS 2.0
- sitemap
- clean output build
- build timezone offsetの再現

現行blogではSwift Publish referenceとMoonBit candidateの全生成ファイルをbyte単位で比較しています。desktop/mobileの主要ページもagent-browserでpixel差分がないことを確認しています。

## Publish汎用機能

### 実装済み

- 複数sectionのcontent model
- root Markdown page
- sectionではないfolder以下の再帰page
- nested item path
- `.md`、`.markdown`、`.txt`、`.text`入力
- custom metadataの保持
- itemの`path` override
- RSS item propertiesのmodel
- audio / video metadataのmodel
- custom HTML factory callback
- index、section、item、page、tag HTML生成
- `foldersAndIndexFiles` / `standAloneFiles`
- tag HTMLの無効化
- configurable RSS feed、section選択、item predicate
- RSS GUID、link、title/body prefix・suffix override
- 複数section・page対応sitemapとexcluded path
- Apple Podcasts / Media RSS互換podcast feed
- podcast author、category、episode、season、explicit metadata
- audio enclosure、duration、sizeの検証error
- composable Predicateとinverse / AND / OR
- item・pageの追加、削除、fallible mutation
- section指定付きitem sortと昇順・降順
- empty、group、conditional、optional、custom publishing step
- plugin installer、custom deployment step、generation/deploymentの実行制御
- 任意file、folder内容、folder自体のcopy step
- target folder指定とtheme resource set
- favicon linkと既定favicon設定
- audio player、hosted/YouTube/Vimeo video player component
- built-in Foundation themeの全location renderer
- Foundation stylesheetとresource書き込み
- Git / GitHub built-in deployment helper
- shell非依存のcommand runner注入とdeployment gating
- CLIのwebsite `new`、`generate`、`run`（既定port 8000・port指定）
- `site.md`による汎用site・section・output設定
- step名で分離した`.publish/Caches`永続cache API
- CLI生成時のRSS feed cache（設定・contentが不変なら以前のfeedを再利用）

### 未実装

- CLIの`new plugin`、`deploy`相当
- podcast feedへの自動cache適用

未実装項目は機能群ごとにtestを先に追加し、既存blogのbyte parityを壊さない形で移行します。

## 互換性の意味

MoonBitとSwiftでは型systemが異なるため、Swift source codeとのAPI互換は目標にしません。目標は次の3点です。

1. 同じcontentと設定から同じ公開fileを生成できること。
2. Publishのpipelineで可能な操作にMoonBit側の代替APIがあること。
3. 差異と未実装機能をこの文書で明示すること。
