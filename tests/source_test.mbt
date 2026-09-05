///|
test "parse Publish item metadata" {
  let source =
    #|
    #|---
    #|date: 2026-05-12 19:10
    #|description: ブログ公開用のスクリプトを一つにまとめた
    #|tags: 技術, 日記,
    #|image: images/example.png
    #|---
    #|
    #|# Title
  let document = @ssg.parse_source(source)
  debug_inspect(
    document.item,
    content=(
      #|{
      #|  title: None,
      #|  description: "ブログ公開用のスクリプトを一つにまとめた",
      #|  date: Some("2026-05-12 19:10"),
      #|  tags: ["技術", "日記"],
      #|  image: Some("images/example.png"),
      #|}
    ),
  )
  inspect(
    document.markdown,
    content=(
      #|
      #|# Title
    ),
  )
}

///|
test "preserve quoted empty descriptions like Publish" {
  let document = @ssg.parse_source(
    (
      #|---
      #|date: 2026-04-24 04:09
      #|description: ""
      #|tags: diary
      #|---
      #|# ブログを書くためのアプリを作った
    ),
  )
  inspect(document.item.description, content="\"\"")
}

///|
test "match Ink metadata edge cases" {
  let document = @ssg.parse_source(
    (
      #|---
      #|a: first
      #|continued value
      #|
      #|empty:
      #|still continued
      #|url: https://example.com/a:b
      #|duplicate: first
      #|duplicate: second
      #|---
      #|Body
    ),
  )
  debug_inspect(
    document.metadata.get("a"),
    content="Some(\"first continued value still continued\")",
  )
  debug_inspect(document.metadata.get("empty"), content="None")
  debug_inspect(document.metadata.get("duplicate"), content="Some(\"second\")")
  debug_inspect(
    document.metadata.get("url"),
    content="Some(\"https://example.com/a:b\")",
  )
}

///|
test "leave Markdown without valid frontmatter untouched" {
  let source = "---\nnot closed\n# Heading\n"
  let document = @ssg.parse_source(source)
  debug_inspect(document.metadata.entries, content="[]")
  inspect(document.markdown, content="---\nnot closed\n# Heading\n")
}
