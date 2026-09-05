///|
fn generic_feed_site() -> @ssg.PublishSiteConfig {
  {
    url: "https://example.com",
    name: "Example & Site",
    description: "Feed <description>",
    language: "en",
    image_path: None,
    favicon_path: None,
  }
}

///|
fn generic_feed_content() -> @ssg.PublishedContent {
  @ssg.build_published_content(
    "# Home",
    [
      {
        id: "articles",
        index_source: Some(
          "---\nlastModified: 2024-01-02 00:00\n---\n# Articles",
        ),
        items: [
          {
            slug: "older",
            source: (
              #|---
              #|date: 2024-01-01 01:02
              #|lastModified: 2024-01-03 00:00
              #|tags: public
              #|---
              #|# Older
            ),
          },
          {
            slug: "newer",
            source: (
              #|---
              #|date: 2025-02-03 04:05
              #|description: News & notes
              #|tags: public
              #|rss.guid: article-2
              #|rss.titlePrefix: [News] 
              #|rss.titleSuffix: !
              #|rss.bodyPrefix: <header>Intro</header>
              #|rss.bodySuffix: <footer><a href="/more">More</a></footer>
              #|rss.link: https://elsewhere.example/item
              #|---
              #|# Newer
              #|
              #|![Image](/image.png)
            ),
          },
        ],
      },
      {
        id: "drafts",
        index_source: None,
        items: [
          {
            slug: "hidden",
            source: "---\ndate: 2026-01-01 00:00\n---\n# Hidden",
          },
        ],
      },
    ],
    [
      {
        path: "about",
        source: "---\nlastModified: 2023-04-05 00:00\n---\n# About",
      },
      {
        path: "private/info",
        source: "---\nlastModified: 2023-01-01 00:00\n---\n# Private",
      },
    ],
  )
}

///|
test "render configurable RSS with section predicate and item overrides" {
  let date = @ssg.BuildDate::parse("2026-09-05T06:42:08+0000").unwrap()
  let html = @ssg.render_publish_rss_feed(
    generic_feed_site(),
    generic_feed_content(),
    ["articles", "drafts"],
    date,
    configuration={
      target_path: "feeds/news.xml",
      ttl: 60,
      maximum_item_count: 1,
    },
    item_predicate=fn(item) { item.tags.contains("public") },
  )
  inspect(html.contains("<title>Example &amp; Site</title>"), content="true")
  inspect(
    html.contains(
      "<atom:link href=\"https://example.com/feeds/news.xml\" rel=\"self\"",
    ),
    content="true",
  )
  inspect(html.contains("<ttl>60</ttl>"), content="true")
  inspect(
    html.contains("<guid isPermaLink=\"false\">article-2</guid>"),
    content="true",
  )
  inspect(html.contains("<title>[News]Newer!</title>"), content="true")
  inspect(
    html.contains("<link>https://elsewhere.example/item</link>"),
    content="true",
  )
  inspect(
    html.contains("<pubDate>Mon, 3 Feb 2025 04:05:00 +0000</pubDate>"),
    content="true",
  )
  inspect(
    html.contains(
      "<header>Intro</header><h1>Newer</h1><img src=\"https://example.com/image.png\" alt=\"Image\"/><footer><a href=\"https://example.com/more\">More</a></footer>",
    ),
    content="true",
  )
  inspect(html.contains("Older"), content="false")
  inspect(html.contains("Hidden"), content="false")
}

///|
test "derive RSS guid permalink behavior from custom links" {
  let content = @ssg.build_published_content(
    "# Home",
    [
      {
        id: "posts",
        index_source: None,
        items: [
          { slug: "default", source: "# Default", },
          {
            slug: "linked",
            source: "---\nrss.link: https://other.example/link\n---\n# Linked",
          },
        ],
      },
    ],
    [],
  )
  let date = @ssg.BuildDate::parse("2026-01-01T00:00:00+0900").unwrap()
  let html = @ssg.render_publish_rss_feed(
    generic_feed_site(),
    content,
    ["posts"],
    date,
  )
  inspect(
    html.contains(
      "<guid isPermaLink=\"true\">https://example.com/posts/default</guid>",
    ),
    content="true",
  )
  inspect(
    html.contains(
      "<guid isPermaLink=\"false\">https://example.com/posts/linked</guid>",
    ),
    content="true",
  )
}

///|
test "render generic sitemap in Publish order with excluded path prefixes" {
  let date = @ssg.BuildDate::parse("2026-09-05T00:00:00+0900").unwrap()
  let xml = @ssg.render_publish_sitemap(
    generic_feed_site(),
    generic_feed_content(),
    date,
    excluded_paths=["drafts", "private"],
  )
  inspect(
    xml,
    content=(
      #|<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:image="http://www.google.com/schemas/sitemap-image/1.1"><url><loc>https://example.com/articles</loc><changefreq>daily</changefreq><priority>1.0</priority><lastmod>2025-02-03</lastmod></url><url><loc>https://example.com/articles/older</loc><changefreq>monthly</changefreq><priority>0.5</priority><lastmod>2024-01-03</lastmod></url><url><loc>https://example.com/articles/newer</loc><changefreq>monthly</changefreq><priority>0.5</priority><lastmod>2025-02-03</lastmod></url><url><loc>https://example.com/about</loc><changefreq>monthly</changefreq><priority>0.5</priority><lastmod>2023-04-05</lastmod></url></urlset>
    ),
  )
}
