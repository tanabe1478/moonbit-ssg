///|
fn foundation_site() -> @ssg.PublishSiteConfig {
  {
    url: "https://example.com",
    name: "Example Site",
    description: "Site description",
    language: "en",
    image_path: Some("images/site.png"),
    favicon_path: Some("images/favicon.png"),
  }
}

///|
fn foundation_content() -> @ssg.PublishedContent {
  @ssg.build_published_content(
    "# Welcome",
    [
      {
        id: "articles",
        index_source: Some("# Articles"),
        items: [
          {
            slug: "older",
            source: "---\ndate: 2024-01-01 00:00\ntags: MoonBit\n---\n# Older",
          },
          {
            slug: "newer",
            source: "---\ndate: 2025-01-01 00:00\ndescription: New post\ntags: SSG\n---\n# Newer",
          },
        ],
      },
      { id: "notes", index_source: Some("# Notes"), items: [], },
    ],
    [{ path: "about", source: "# About", }],
  )
}

///|
test "generate every location with the Publish Foundation theme" {
  let root = "/tmp/moonbit-ssg-foundation-\{@env.now()}"
  let content = foundation_content()
  @ssg.generate_publish_html(
    root,
    content,
    @ssg.foundation_html_factory(foundation_site()),
    tag_base_path="tags",
  )
  @ssg.write_foundation_stylesheet(root)
  let index = @fs.read_file_to_string(test_join_path(root, "index.html"))
  inspect(index.contains("<h2>Latest content</h2>"), content="true")
  inspect(
    match index.split_once("Newer") {
      Some((_prefix, suffix)) => suffix.contains("Older")
      None => false
    },
    content="true",
  )
  inspect(
    index.contains("<link rel=\"stylesheet\" href=\"/styles.css\""),
    content="true",
  )
  inspect(
    index.contains("<link rel=\"shortcut icon\" href=\"/images/favicon.png\""),
    content="true",
  )
  let section = @fs.read_file_to_string(
    test_join_path(root, "articles/index.html"),
  )
  inspect(
    section.contains("<a class=\"selected\" href=\"/articles\">Articles</a>"),
    content="true",
  )
  let item = @fs.read_file_to_string(
    test_join_path(root, "articles/newer/index.html"),
  )
  inspect(item.contains("<body class=\"item-page\">"), content="true")
  inspect(item.contains("Tagged with: "), content="true")
  let tags = @fs.read_file_to_string(test_join_path(root, "tags/index.html"))
  inspect(tags.contains("Browse all tags"), content="true")
  inspect(tags.contains("/tags/moonbit"), content="true")
  let css = @fs.read_file_to_string(test_join_path(root, "styles.css"))
  inspect(css.contains("Publish Foundation theme"), content="true")
  inspect(css.contains(".item-list > li"), content="true")
  test_remove_tree(root)
}
