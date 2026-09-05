///|
/// Site metadata shared by generic HTML, feed, and sitemap generation.
pub(all) struct PublishSiteConfig {
  url : String
  name : String
  description : String
  language : String
  image_path : String?
  favicon_path : String?
} derive(Eq, Debug)

///|
/// Configuration equivalent to Publish's RSSFeedConfiguration.
pub(all) struct PublishRSSConfiguration {
  target_path : String
  ttl : Int
  maximum_item_count : Int
} derive(Eq, Debug)

///|
pub fn default_publish_rss_configuration() -> PublishRSSConfiguration {
  { target_path: "feed.rss", ttl: 250, maximum_item_count: 100, }
}

///|
fn publish_absolute_url(config : PublishSiteConfig, path : String) -> String {
  if path.has_prefix("http://") || path.has_prefix("https://") {
    return path
  }
  let base = if config.url.has_suffix("/") {
    config.url[:config.url.length() - 1].to_owned()
  } else {
    config.url
  }
  let path = if path.has_prefix("/") { path } else { "/\{path}" }
  "\{base}\{path}"
}

///|
fn generic_content_date(value : String, utc_offset : String) -> BuildDate {
  let normalized = value.replace_all(old=" ", new="T")
  let timestamp = if normalized.length() == 16 {
    normalized + ":00" + utc_offset
  } else if normalized.length() == 19 {
    normalized + utc_offset
  } else {
    ""
  }
  BuildDate::parse(timestamp).unwrap_or({
    year: 1970,
    month: 1,
    day: 1,
    hour: 0,
    minute: 0,
    second: 0,
    utc_offset,
  })
}

///|
fn generic_rss_body(config : PublishSiteConfig, item : PublishItem) -> String {
  let html = item.rss.body_prefix.unwrap_or("") +
    item.content.body_html +
    item.rss.body_suffix.unwrap_or("")
  html
  .replace_all(old="src=\"/", new="src=\"\{config.url}/")
  .replace_all(old="href=\"/", new="href=\"\{config.url}/")
}

///|
fn generic_rss_guid(config : PublishSiteConfig, item : PublishItem) -> String {
  let item_url = publish_absolute_url(config, item.path())
  match item.rss.guid {
    Some(guid) => "<guid isPermaLink=\"false\">\{xml_text(guid)}</guid>"
    None => {
      let is_permalink = if item.rss.link is None { "true" } else { "false" }
      "<guid isPermaLink=\"\{is_permalink}\">\{item_url}</guid>"
    }
  }
}

///|
fn included_publish_items(
  content : PublishedContent,
  section_ids : Array[String],
  predicate : ((PublishItem) -> Bool)?,
) -> Array[PublishItem] {
  let items : Array[PublishItem] = []
  for section in content.sections {
    if section_ids.contains(section.id) {
      for item in section.items {
        let included = match predicate {
          Some(matches) => matches(item)
          None => true
        }
        if included {
          items.push(item)
        }
      }
    }
  }
  items.sort_by(fn(left, right) {
    right.content.date.compare(left.content.date)
  })
  items
}

///|
/// Renders a configurable Publish-compatible RSS 2.0 feed.
pub fn render_publish_rss_feed(
  site : PublishSiteConfig,
  content : PublishedContent,
  section_ids : Array[String],
  build_date : BuildDate,
  configuration? : PublishRSSConfiguration = default_publish_rss_configuration(),
  item_predicate? : (PublishItem) -> Bool,
) -> String {
  let source_items = included_publish_items(
    content, section_ids, item_predicate,
  )
  let item_count = if source_items.length() < configuration.maximum_item_count {
    source_items.length()
  } else {
    configuration.maximum_item_count
  }
  let items : Array[String] = []
  for index = 0; index < item_count; index = index + 1 {
    let item = source_items[index]
    let item_url = publish_absolute_url(site, item.path())
    let link = item.rss.link.unwrap_or(item_url)
    items.push(
      "<item>\{generic_rss_guid(site, item)}<title>\{xml_text(item.rss_title())}</title><description>\{xml_text(item.content.description)}</description><link>\{xml_text(link)}</link><pubDate>\{rfc822_date(generic_content_date(item.content.date, build_date.utc_offset))}</pubDate><content:encoded><![CDATA[\{generic_rss_body(site, item)}]]></content:encoded></item>",
    )
  }
  let built = rfc822_date(build_date)
  let feed_url = publish_absolute_url(site, configuration.target_path)
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?><rss version=\"2.0\" xmlns:atom=\"http://www.w3.org/2005/Atom\" xmlns:content=\"http://purl.org/rss/1.0/modules/content/\"><channel><title>\{xml_text(site.name)}</title><description>\{xml_text(site.description)}</description><link>\{site.url}</link><language>\{site.language}</language><lastBuildDate>\{built}</lastBuildDate><pubDate>\{built}</pubDate><ttl>\{configuration.ttl}</ttl><atom:link href=\"\{feed_url}\" rel=\"self\" type=\"application/rss+xml\"/>\{items.join("")}</channel></rss>"
}

///|
/// Renders an RSS feed while preserving the previous feed when all inputs
/// except the build date are unchanged.
pub fn render_cached_publish_rss_feed(
  root_directory : String,
  site : PublishSiteConfig,
  content : PublishedContent,
  section_ids : Array[String],
  build_date : BuildDate,
  configuration? : PublishRSSConfiguration = default_publish_rss_configuration(),
  item_predicate? : (PublishItem) -> Bool,
  step_name? : String = "Generate RSS feed",
) -> Result[PublishCacheValue, String] {
  let cache_key = render_publish_rss_feed(
    site,
    content,
    section_ids,
    publish_cache_build_date(build_date),
    configuration~,
    item_predicate?,
  )
  Ok(
    cached_publish_value(root_directory, step_name, "feed", cache_key, fn() {
      render_publish_rss_feed(
        site,
        content,
        section_ids,
        build_date,
        configuration~,
        item_predicate?,
      )
    }),
  ) catch {
    @fs.IOError(message) => Err(message)
  }
}

///|
fn publish_last_modified_day(value : String, fallback : String) -> String {
  if value.length() >= 10 {
    value[:10].to_owned()
  } else {
    fallback
  }
}

///|
fn publish_path_is_included(
  path : String,
  excluded_paths : Array[String],
) -> Bool {
  let normalized = path.trim(chars=['/']).to_owned()
  for excluded in excluded_paths {
    if normalized.has_prefix(excluded.trim(chars=['/'])) {
      return false
    }
  }
  true
}

///|
/// Renders sections, items, and free-form pages using Publish's sitemap order
/// and prefix-based path exclusion behavior.
pub fn render_publish_sitemap(
  site : PublishSiteConfig,
  content : PublishedContent,
  build_date : BuildDate,
  excluded_paths? : Array[String] = [],
) -> String {
  let fallback = "\{build_date.year}-\{two_digits(build_date.month)}-\{two_digits(build_date.day)}"
  let entries : Array[String] = []
  let sections = content.sections.map(fn(section) { section })
  sections.sort_by(fn(left, right) { left.id.compare(right.id) })
  for section in sections {
    if !publish_path_is_included(section.id, excluded_paths) {
      continue
    }
    let mut section_modified = section.content.last_modified
    for item in section.items {
      if item.content.last_modified.compare(section_modified) > 0 {
        section_modified = item.content.last_modified
      }
    }
    entries.push(
      sitemap_entry(
        publish_absolute_url(site, section.id),
        "daily",
        "1.0",
        publish_last_modified_day(section_modified, fallback),
      ),
    )
    for item in section.items {
      if publish_path_is_included(item.path(), excluded_paths) {
        entries.push(
          sitemap_entry(
            publish_absolute_url(site, item.path()),
            "monthly",
            "0.5",
            publish_last_modified_day(item.content.last_modified, fallback),
          ),
        )
      }
    }
  }
  let pages = content.pages.map(fn(page) { page })
  pages.sort_by(fn(left, right) { left.path.compare(right.path) })
  for page in pages {
    if publish_path_is_included(page.path, excluded_paths) {
      entries.push(
        sitemap_entry(
          publish_absolute_url(site, page.path),
          "monthly",
          "0.5",
          publish_last_modified_day(page.content.last_modified, fallback),
        ),
      )
    }
  }
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?><urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\" xmlns:image=\"http://www.google.com/schemas/sitemap-image/1.1\">\{entries.join("")}</urlset>"
}
