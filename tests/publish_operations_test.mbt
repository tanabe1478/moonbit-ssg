///|
fn operations_content() -> @ssg.PublishedContent {
  @ssg.build_published_content(
    "# Home",
    [
      {
        id: "posts",
        index_source: None,
        items: [
          {
            slug: "older",
            source: "---\ndate: 2024-01-01 00:00\ntags: keep\n---\n# Older",
          },
          {
            slug: "newer",
            source: "---\ndate: 2025-01-01 00:00\ntags: remove\n---\n# Newer",
          },
        ],
      },
      {
        id: "notes",
        index_source: None,
        items: [{ slug: "note", source: "# Note", }],
      },
    ],
    [{ path: "about", source: "# About", }],
  )
}

///|
fn item_with_title(item : @ssg.PublishItem, title : String) -> @ssg.PublishItem {
  let original = item.content
  {
    section_id: item.section_id,
    relative_path: item.relative_path,
    metadata: item.metadata,
    tags: item.tags,
    content: {
      title,
      description: original.description,
      body_html: original.body_html,
      date: original.date,
      last_modified: original.last_modified,
      image_path: original.image_path,
      audio: original.audio,
      video: original.video,
    },
    rss: item.rss,
  }
}

///|
test "compose predicates and remove items in one section" {
  let tagged = @ssg.publish_predicate(fn(item : @ssg.PublishItem) {
    item.tags.contains("remove")
  })
  let posts = @ssg.publish_predicate(fn(item : @ssg.PublishItem) {
    item.section_id == "posts"
  })
  let predicate = tagged
    .and_also(posts)
    .or_else(posts.inverse().and_also(tagged))
  let content = @ssg.remove_publish_items(
    operations_content(),
    predicate,
    section_id="posts",
  )
  debug_inspect(
    content.sections[0].items.map(fn(item) { item.relative_path }),
    content="[\"older\"]",
  )
  debug_inspect(
    content.sections[1].items.map(fn(item) { item.relative_path }),
    content="[\"note\"]",
  )
}

///|
test "add and mutate Publish items and pages immutably" {
  let added = @ssg.add_publish_item(
    operations_content(),
    @ssg.build_publish_item("posts", "third", "# Third"),
  ).unwrap()
  let mutated = @ssg.mutate_publish_item(added, "posts", "third", fn(item) {
    Ok(item_with_title(item, "Changed"))
  }).unwrap()
  inspect(mutated.sections[0].items[2].content.title, content="Changed")
  inspect(added.sections[0].items[2].content.title, content="Third")
  let with_page = @ssg.add_publish_page(
    mutated,
    @ssg.build_publish_page("contact", "# Contact"),
  )
  let changed_pages = @ssg.mutate_publish_pages(
    with_page,
    @ssg.publish_predicate(fn(page : @ssg.PublishPage) {
      page.path == "contact"
    }),
    fn(page) { Ok({ path: "support", content: page.content, }) },
  ).unwrap()
  debug_inspect(
    changed_pages.pages.map(fn(page) { page.path }),
    content="[\"about\", \"support\"]",
  )
}

///|
test "sort selected Publish sections with either order" {
  let descending = @ssg.sort_publish_items(
    operations_content(),
    fn(left, right) { left.content.date.compare(right.content.date) },
    order=@ssg.Descending,
    section_id="posts",
  )
  debug_inspect(
    descending.sections[0].items.map(fn(item) { item.content.title }),
    content="[\"Newer\", \"Older\"]",
  )
  debug_inspect(
    descending.sections[1].items.map(fn(item) { item.content.title }),
    content="[\"Note\"]",
  )
}

///|
test "wrap mutation failures with location paths" {
  let item_error = @ssg.mutate_publish_item(
    operations_content(),
    "posts",
    "older",
    fn(_item) { Err("invalid title") },
  )
  debug_inspect(
    item_error,
    content="Err(\"/posts/older: item mutation failed: invalid title\")",
  )
  let missing = @ssg.add_publish_item(
    operations_content(),
    @ssg.build_publish_item("missing", "item", "# Item"),
  )
  debug_inspect(missing, content="Err(\"unknown section: missing\")")
}
