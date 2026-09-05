# moonbit-ssg

Publish互換を目標にした、MoonBit製の静的サイトジェネレーターです。

現在はプロジェクトの土台だけを実装しています。Swift Publishによる既存サイトを正解として、生成結果を比較しながら段階的に機能を追加します。

## 開発環境

MoonBit toolchainは[mise](https://mise.jdx.dev/)で管理します。

```sh
mise install
mise run check
mise exec -- moon run cmd/main
```

実行結果:

```text
moonbit-ssg 0.1.0
```

`mise.toml`はMoonBit `0.10.11+6ff76a5f9`を固定しています。mise組み込みのHTTP backendで公式archiveを取得し、toolchainと標準libraryのSHA-256を検証します。

## プロジェクト構成

```text
.
├── cmd/main/       # CLIの実行可能package
├── ssg.mbt         # 再利用可能なlibrary API
├── ssg_test.mbt    # libraryを外側から確認するblack-box test
├── moon.mod        # module全体のmetadata
├── moon.pkg        # root packageの定義
└── mise.toml       # toolchainと開発task
```

MoonBitでは、`moon.mod`を持つプロジェクト全体を**module**、`moon.pkg`を持つ各directoryを**package**として扱います。このmoduleには、rootのlibrary packageと`cmd/main`のexecutable packageがあります。

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

`source.mbt`の`parse_source`は、Markdownをfrontmatterと本文に分けます。

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

この互換性は`source_test.mbt`のblack-box testで固定しています。

## 移行の検証方針

最終的には同じブログ入力から次の2つを生成します。

```text
Swift Publish -> reference output
moonbit-ssg   -> candidate output
```

最初はファイル構成と内容のbyte-for-byte一致を目標にします。その後、固定viewportのブラウザ表示と主要ページの動作も比較してから本番生成器を切り替えます。
