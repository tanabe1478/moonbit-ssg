///|
test "load Publish Markdown folder layout" {
  let root = "/tmp/moonbit-ssg-publish-content-\{@env.now()}"
  test_ensure_directory(test_join_path(root, "ARTICLES/nested"))
  test_ensure_directory(test_join_path(root, "company/team"))
  @fs.write_string_to_file(test_join_path(root, "index.md"), "# Home")
  @fs.write_string_to_file(test_join_path(root, "contact.txt"), "# Contact")
  @fs.write_string_to_file(
    test_join_path(root, "ARTICLES/index.text"),
    "# Articles",
  )
  @fs.write_string_to_file(
    test_join_path(root, "ARTICLES/first.markdown"),
    "# First",
  )
  @fs.write_string_to_file(
    test_join_path(root, "ARTICLES/nested/second.txt"),
    "# Second",
  )
  @fs.write_string_to_file(
    test_join_path(root, "company/index.md"),
    "# Company",
  )
  @fs.write_string_to_file(
    test_join_path(root, "company/team/about.md"),
    "# Team",
  )
  @fs.write_string_to_file(test_join_path(root, "ignored.json"), "{}")
  let site = @ssg.load_published_content(root, ["articles", "empty"])
  inspect(site.index.title, content="Home")
  debug_inspect(
    site.sections.map(fn(section) { section.id }),
    content="[\"articles\", \"empty\"]",
  )
  inspect(site.sections[0].content.title, content="Articles")
  debug_inspect(
    site.sections[0].items.map(fn(item) { item.relative_path }),
    content="[\"first\", \"nested/second\"]",
  )
  debug_inspect(
    site.pages.map(fn(page) { page.path }),
    content="[\"company/index\", \"company/team/about\", \"contact\"]",
  )
  test_remove_tree(root)
}
