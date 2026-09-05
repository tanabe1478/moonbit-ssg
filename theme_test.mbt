///|
fn test_config() -> @moonbit-ssg.SiteConfig {
  {
    url: "https://example.com",
    name: "Example",
    description: "Site description",
    language: "en",
    image_path: "/images/logo.png",
    favicon_path: "/images/favicon.png",
    stylesheet_path: "/styles.css",
    feed_path: "/feed.rss",
    analytics_id: "G-TEST",
    x_url: "https://x.com/example",
    github_url: "https://github.com/example",
  }
}

///|
fn test_site() -> @moonbit-ssg.SiteContent {
  @moonbit-ssg.build_site_content("# ", "# My posts", [
    {
      slug: "older",
      source: (
        #|---
        #|date: 2024-01-02 03:04
        #|description: Older & useful
        #|tags: 技術
        #|---
        #|# Older title
      ),
    },
    {
      slug: "newer",
      source: (
        #|---
        #|date: 2025-06-07 08:09
        #|description: ""
        #|tags: diary, 技術
        #|---
        #|# Newer title
      ),
    },
  ])
}

///|
test "render index metadata, profile, and descending items" {
  let html = @moonbit-ssg.render_index_page(test_config(), test_site())
  assert_true(
    html.has_prefix(
      "<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"UTF-8\"/><meta name=\"og:site_name\" content=\"Example\"/><link rel=\"canonical\" href=\"https://example.com\"/>",
    ),
  )
  assert_true(html.contains("gtag('config', 'G-TEST')"))
  assert_true(
    html.contains(
      "<div class=\"profile-links\"><a class=\"icon-link\" href=\"https://x.com/example\"",
    ),
  )
  let newer = html.find("/posts/newer").unwrap()
  let older = html.find("/posts/older").unwrap()
  assert_true(newer < older)
  assert_true(
    html.has_suffix("<footer><a href=\"/\">Home</a></footer></body></html>"),
  )
}

///|
test "render section in source order" {
  let html = @moonbit-ssg.render_section_page(test_config(), test_site())
  assert_true(html.contains("<title>My posts | Example</title>"))
  let older = html.find("/posts/older").unwrap()
  let newer = html.find("/posts/newer").unwrap()
  assert_true(older < newer)
}

///|
test "render post detail without custom analytics nodes" {
  let site = test_site()
  let html = @moonbit-ssg.render_post_page(test_config(), site.posts[1])
  assert_true(
    html.contains(
      "<link rel=\"canonical\" href=\"https://example.com/posts/newer\"/>",
    ),
  )
  assert_true(html.contains("<meta name=\"description\" content=\"\"\"\"/>"))
  assert_false(html.contains("googletagmanager"))
  assert_true(
    html.contains(
      "<body class=\"item-page\"><header><div class=\"wrapper\"><a class=\"site-name\" href=\"/\">Example</a></div></header>",
    ),
  )
  assert_true(
    html.contains(
      "<header class=\"article-header\"><h1>Newer title</h1><div class=\"article-meta\"><span>2025-06-07</span></div></header>",
    ),
  )
}

///|
test "render sorted tag navigation and filtered details" {
  let tags = @moonbit-ssg.render_tag_list_page(test_config(), test_site())
  assert_true(
    tags.find("/tags/diary").unwrap() < tags.find("/tags/技術").unwrap(),
  )
  let details = @moonbit-ssg.render_tag_details_page(
    test_config(),
    test_site(),
    "技術",
  )
  assert_true(
    details.contains(
      "<h1>Tagged with <span class=\"tag\">技術</span></h1><a class=\"browse-all\" href=\"/tags\">Browse all tags</a>",
    ),
  )
  assert_true(
    details.find("/posts/newer").unwrap() <
    details.find("/posts/older").unwrap(),
  )
}
