///|
test "generate HTML with custom factory and standalone file mode" {
  let root = "/tmp/moonbit-ssg-publish-html-\{@env.now()}"
  let content = @ssg.build_published_content(
    "# Home",
    [
      {
        id: "articles",
        index_source: Some("# Articles"),
        items: [
          { slug: "nested/hello", source: "---\ntags: Moon Bit\n---\n# Hello", },
        ],
      },
    ],
    [{ path: "about/team", source: "# Team", }],
  )
  let factory : @ssg.PublishHTMLFactory = {
    make_index: fn(index, _site) { "index:\{index.title}" },
    make_section: fn(section, _site) { "section:\{section.content.title}" },
    make_item: fn(item, _site) { "item:\{item.content.title}" },
    make_page: fn(page, _site) { "page:\{page.content.title}" },
    make_tag_list: fn(tags, _site) { Some("tags:\{tags.join(",")}") },
    make_tag_details: fn(tag, items, _site) {
      Some("tag:\{tag}:\{items.length()}")
    },
  }
  @ssg.generate_publish_html(
    root,
    content,
    factory,
    file_mode=@ssg.StandAloneFiles,
    tag_base_path="topics",
  )
  inspect(
    @fs.read_file_to_string(test_join_path(root, "index.html")),
    content="index:Home",
  )
  inspect(
    @fs.read_file_to_string(test_join_path(root, "articles/index.html")),
    content="section:Articles",
  )
  inspect(
    @fs.read_file_to_string(test_join_path(root, "articles/nested/hello.html")),
    content="item:Hello",
  )
  inspect(
    @fs.read_file_to_string(test_join_path(root, "about/team.html")),
    content="page:Team",
  )
  inspect(
    @fs.read_file_to_string(test_join_path(root, "topics/index.html")),
    content="tags:Moon Bit",
  )
  inspect(
    @fs.read_file_to_string(test_join_path(root, "topics/moon-bit.html")),
    content="tag:Moon Bit:1",
  )
  test_remove_tree(root)
}

///|
test "generate folders and index files without tag HTML" {
  let root = "/tmp/moonbit-ssg-publish-folders-\{@env.now()}"
  let content = @ssg.build_published_content(
    "# Home",
    [
      {
        id: "notes",
        index_source: None,
        items: [{ slug: "one", source: "# One", }],
      },
    ],
    [],
  )
  let factory : @ssg.PublishHTMLFactory = {
    make_index: fn(_index, _site) { "index" },
    make_section: fn(_section, _site) { "section" },
    make_item: fn(_item, _site) { "item" },
    make_page: fn(_page, _site) { "page" },
    make_tag_list: fn(_tags, _site) { None },
    make_tag_details: fn(_tag, _items, _site) { None },
  }
  @ssg.generate_publish_html(root, content, factory)
  inspect(
    @fs.read_file_to_string(test_join_path(root, "notes/one/index.html")),
    content="item",
  )
  inspect(@fs.path_exists(test_join_path(root, "tags")), content="false")
  test_remove_tree(root)
}
