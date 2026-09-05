///|
fn feed_config() -> @ssg.SiteConfig {
  {
    url: "https://example.com",
    name: "Example & Blog",
    description: "Site & feed",
    language: "en",
    image_path: "/logo.png",
    favicon_path: "/favicon.png",
    stylesheet_path: "/styles.css",
    feed_path: "/feed.rss",
    analytics_id: "",
    x_url: "",
    github_url: "",
  }
}

///|
fn feed_site() -> @ssg.SiteContent {
  @ssg.build_site_content("# ", "# Posts", [
    {
      slug: "older",
      source: (
        #|---
        #|date: 2024-01-02 03:04
        #|description: Older & useful
        #|tags: test
        #|---
        #|# Older
        #|
        #|Body
      ),
    },
    {
      slug: "newer",
      source: (
        #|---
        #|date: 2025-06-07 08:09
        #|description: ""
        #|tags: test
        #|---
        #|# Newer
        #|
        #|New body
        #|
        #|![Alt](/image.png)
      ),
    },
  ])
}

///|
test "parse deterministic build date" {
  debug_inspect(
    @ssg.BuildDate::parse("2026-09-05T13:44:37"),
    content=(
      #|Some(
      #|  {
      #|    year: 2026,
      #|    month: 9,
      #|    day: 5,
      #|    hour: 13,
      #|    minute: 44,
      #|    second: 37,
      #|    utc_offset: "+0900",
      #|  },
      #|)
    ),
  )
  inspect(
    @ssg.BuildDate::parse("2026-09-05T06:42:08+0000").unwrap().utc_offset,
    content="+0000",
  )
  debug_inspect(@ssg.BuildDate::parse("2026-09-05"), content="None")
}

///|
test "render Publish-compatible RSS" {
  let date = @ssg.BuildDate::parse("2026-09-05T13:44:37").unwrap()
  inspect(
    @ssg.render_rss_feed(feed_config(), feed_site(), date),
    content=(
      #|<?xml version="1.0" encoding="UTF-8"?><rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom" xmlns:content="http://purl.org/rss/1.0/modules/content/"><channel><title>Example &amp; Blog</title><description>Site &amp; feed</description><link>https://example.com</link><language>en</language><lastBuildDate>Sat, 5 Sep 2026 13:44:37 +0900</lastBuildDate><pubDate>Sat, 5 Sep 2026 13:44:37 +0900</pubDate><ttl>250</ttl><atom:link href="https://example.com/feed.rss" rel="self" type="application/rss+xml"/><item><guid isPermaLink="true">https://example.com/posts/newer</guid><title>Newer</title><description>""</description><link>https://example.com/posts/newer</link><pubDate>Sat, 7 Jun 2025 08:09:00 +0900</pubDate><content:encoded><![CDATA[<h1>Newer</h1><p>New body</p><img src="https://example.com/image.png" alt="Alt"/>]]></content:encoded></item><item><guid isPermaLink="true">https://example.com/posts/older</guid><title>Older</title><description>Older &amp; useful</description><link>https://example.com/posts/older</link><pubDate>Tue, 2 Jan 2024 03:04:00 +0900</pubDate><content:encoded><![CDATA[<h1>Older</h1><p>Body</p>]]></content:encoded></item></channel></rss>
    ),
  )
}

///|
test "render Publish-compatible sitemap" {
  let date = @ssg.BuildDate::parse("2026-09-05T13:44:37").unwrap()
  inspect(
    @ssg.render_sitemap(feed_config(), feed_site(), date),
    content=(
      #|<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:image="http://www.google.com/schemas/sitemap-image/1.1"><url><loc>https://example.com/posts</loc><changefreq>daily</changefreq><priority>1.0</priority><lastmod>2026-09-05</lastmod></url><url><loc>https://example.com/posts/newer</loc><changefreq>monthly</changefreq><priority>0.5</priority><lastmod>2026-09-05</lastmod></url><url><loc>https://example.com/posts/older</loc><changefreq>monthly</changefreq><priority>0.5</priority><lastmod>2026-09-05</lastmod></url></urlset>
    ),
  )
}
