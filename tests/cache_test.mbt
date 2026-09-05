///|
test "persist values in a publishing-step-scoped cache" {
  let root = "/tmp/moonbit-ssg-cache-\{@env.now()}"
  let produced : Array[String] = []
  let first = @ssg.cached_publish_value(
    root,
    "Generate RSS feed",
    "feed",
    "日本語-key",
    fn() {
      produced.push("first")
      "cached feed"
    },
  )
  inspect(first.value, content="cached feed")
  inspect(first.reused, content="false")
  inspect(
    first.path.has_suffix(".publish/Caches/generate-rss-feed/feed"),
    content="true",
  )
  let second = @ssg.cached_publish_value(
    root,
    "Generate RSS feed",
    "feed",
    "日本語-key",
    fn() {
      produced.push("second")
      "replacement"
    },
  )
  inspect(second.value, content="cached feed")
  inspect(second.reused, content="true")
  debug_inspect(produced, content="[\"first\"]")
  let changed = @ssg.cached_publish_value(
    root,
    "Generate RSS feed",
    "feed",
    "changed-key",
    fn() { "new feed" },
  )
  inspect(changed.value, content="new feed")
  inspect(changed.reused, content="false")
  test_remove_tree(root)
}
