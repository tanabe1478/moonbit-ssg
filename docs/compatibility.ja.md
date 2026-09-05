# Publish 0.9互換範囲

[English](compatibility.md)

比較対象はSwift Publish `0.9.0`（revision `1c8ad00d39c985cb5d497153241a2f1b654e0d40`）です。

互換性は、`tanabe1478/blog`の正確な移行contractと、Publish framework全体の再利用可能な機能に分けて管理します。Swift source levelのAPI互換は目標にしません。

## tanabe1478/blogの移行contract

実装済み:

- Ink互換frontmatter
- Markdown HTML変換
- YouTube modifier
- shell / Swift syntax highlight markup
- index、posts section、item、tag list、tag details page
- custom theme metadata、canonical URL、Open Graph、Analytics
- Resourcesとtheme stylesheetの再帰copy
- RSS 2.0
- sitemap
- clean output build
- build timezone offsetの維持

blog repositoryからSwift Publishを削除する前に、88個の生成fileがbyte単位で一致することを確認しました。index、最新記事、tag list、移行記事のdesktop/mobile表示でもpixel差分0を確認済みです。現在のblog本番出力はmoonbit-ssgだけで生成します。

## Publishの汎用機能

実装済み:

- 複数sectionのcontent model
- root Markdown page
- sectionではないdirectory以下の再帰page
- nested item path
- `.md`、`.markdown`、`.txt`、`.text`入力
- custom metadata保持
- itemの`path` override
- RSS item properties
- audio / video metadata
- callback式custom HTML factory
- index、section、item、page、tag list、tag details生成
- `FoldersAndIndexFiles` / `StandAloneFiles`
- tag HTML生成の無効化
- configurable RSS、section選択、item predicate
- RSS GUID、link、title/body prefix・suffix override
- 複数section/pageとexcluded path対応sitemap
- Apple Podcasts / Media RSS互換podcast feed
- podcast author、category、episode、season、explicit metadata
- audio enclosure、duration、size検証
- inverse、AND、ORで合成できるpredicate
- immutableなitem/page追加、削除、mutation、section sort
- 昇順・降順sort
- empty、group、conditional、optional、custom、generation、deployment step
- plugin installとdeployment gating
- file、directory内容、directory、theme resource copy step
- target directory指定
- favicon描画とdefault
- audio、hosted/YouTube/Vimeo video component
- 全location対応の組み込みFoundation renderer
- Foundation stylesheet/resource書込
- runner注入式Git/GitHub deployment helper
- 補間shell文字列を使わないexecutable/argument分離
- CLI website `new`、`generate`、`run`
- 汎用`site.md`設定
- step単位の`.publish/Caches`永続cache API
- RSS / podcast feed cache
- 永続checkout、branch fallback、同期、pushを行うCLI Git `deploy`
- CLI `new plugin` package scaffold

## 既知の差異

Swift Publishの`new plugin`はremote package dependencyを含む完全なSwift Packageを作ります。MoonBit module manifestはpackage registryにないGit dependencyを直接宣言できません。そのためMoonBit版は、既存module内へ`moon.pkg`とplugin sourceを作ります。親moduleがdependency宣言とversion選択を管理します。

## 互換性の意味

MoonBitとSwiftでは型system、error処理、mutation model、package managerが異なります。ここでの互換性は次を意味します。

1. 同等のcontentと設定から同等の公開fileを生成できること。
2. Publish pipelineの操作にMoonBit向けの代替APIがあること。
3. 既知の挙動・packaging差異を文書化すること。

Swiftのthrowing/inout APIは原則として、`Result`を返すimmutable関数に置き換えます。Swift generic protocolよりMoonBitで明確になる箇所ではcallback factoryを使います。
