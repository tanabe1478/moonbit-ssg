///|
/// Values used by the Publish-compatible HTML theme.
pub(all) struct SiteConfig {
  url : String
  name : String
  description : String
  language : String
  image_path : String
  favicon_path : String
  stylesheet_path : String
  feed_path : String
  analytics_id : String
  x_url : String
  github_url : String
} derive(Eq, Debug)

///|
fn is_url_path_byte(byte : Int) -> Bool {
  (byte >= 0x41 && byte <= 0x5a) ||
  (byte >= 0x61 && byte <= 0x7a) ||
  (byte >= 0x30 && byte <= 0x39) ||
  byte == 0x2f ||
  byte == 0x2d ||
  byte == 0x2e ||
  byte == 0x5f ||
  byte == 0x7e
}

///|
fn percent_encoded_path(path : String) -> String {
  let hex = "0123456789ABCDEF".to_array()
  let output = StringBuilder()
  for byte in @utf8.encode(path) {
    let value = byte.to_int()
    if is_url_path_byte(value) {
      output.write_char(byte.to_char())
    } else {
      output.write_char('%')
      output.write_char(hex[value / 16])
      output.write_char(hex[value % 16])
    }
  }
  output.to_string()
}

///|
fn absolute_url(config : SiteConfig, path : String) -> String {
  if path.is_empty() || path == "/" {
    config.url
  } else if path.has_prefix("/") {
    "\{config.url}\{percent_encoded_path(path)}"
  } else {
    "\{config.url}/\{percent_encoded_path(path)}"
  }
}

///|
fn page_title(config : SiteConfig, title : String) -> String {
  if title.is_empty() {
    config.name
  } else {
    "\{title} | \{config.name}"
  }
}

///|
fn render_head(
  config : SiteConfig,
  path : String,
  title : String,
  description : String,
  image_path : String?,
  custom_nodes : Bool,
) -> String {
  let canonical = absolute_url(config, path)
  let title = page_title(config, title)
  let description = if description.is_empty() {
    config.description
  } else {
    description
  }
  let social_image = absolute_url(
    config,
    image_path.unwrap_or(config.image_path),
  )
  let card_type = match image_path {
    Some(_) => "summary_large_image"
    None => "summary"
  }
  let analytics = if custom_nodes && !config.analytics_id.is_empty() {
    "<script async src=\"https://www.googletagmanager.com/gtag/js?id=\{config.analytics_id}\"></script><script>window.dataLayer = window.dataLayer || [];function gtag(){dataLayer.push(arguments);}gtag('js', new Date());gtag('config', '\{config.analytics_id}');</script>"
  } else {
    ""
  }
  "<head><meta charset=\"UTF-8\"/><meta name=\"og:site_name\" content=\"\{config.name}\"/><link rel=\"canonical\" href=\"\{canonical}\"/><meta name=\"twitter:url\" content=\"\{canonical}\"/><meta name=\"og:url\" content=\"\{canonical}\"/><title>\{escape_html(title)}</title><meta name=\"twitter:title\" content=\"\{title}\"/><meta name=\"og:title\" content=\"\{title}\"/><meta name=\"description\" content=\"\{description}\"/><meta name=\"twitter:description\" content=\"\{description}\"/><meta name=\"og:description\" content=\"\{description}\"/><meta name=\"twitter:card\" content=\"\{card_type}\"/><link rel=\"stylesheet\" href=\"\{config.stylesheet_path}\" type=\"text/css\"/><meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\"/><link rel=\"shortcut icon\" href=\"\{config.favicon_path}\" type=\"image/png\"/><link rel=\"alternate\" href=\"\{config.feed_path}\" type=\"application/rss+xml\" title=\"Subscribe to \{config.name}\"/><meta name=\"twitter:image\" content=\"\{social_image}\"/><meta name=\"og:image\" content=\"\{social_image}\"/>\{analytics}</head>"
}

///|
fn render_header(config : SiteConfig) -> String {
  "<header><div class=\"wrapper\"><a class=\"site-name\" href=\"/\">\{escape_html(config.name)}</a></div></header>"
}

///|
fn render_footer() -> String {
  "<footer><a href=\"/\">Home</a></footer>"
}

///|
fn render_document(
  config : SiteConfig,
  path : String,
  title : String,
  description : String,
  body : String,
  item_page : Bool,
  image_path : String?,
  custom_head : Bool,
) -> String {
  let body_class = if item_page { " class=\"item-page\"" } else { "" }
  "<!DOCTYPE html><html lang=\"\{config.language}\">\{render_head(config, path, title, description, image_path, custom_head)}<body\{body_class}>\{render_header(config)}\{body}\{render_footer()}</body></html>"
}

///|
fn render_tag_list(post : Post) -> String {
  let tags : Array[String] = []
  for tag in post.tags {
    tags.push("<li><a href=\"/tags/\{tag}\">\{escape_html(tag)}</a></li>")
  }
  "<ul class=\"tag-list\">\{tags.join("")}</ul>"
}

///|
fn render_item_list(posts : Array[Post]) -> String {
  let items : Array[String] = []
  for post in posts {
    items.push(
      "<li><article class=\"item-row\"><span class=\"item-date\">\{post.date_day()}</span><h1><a class=\"item-title\" href=\"\{post.path()}\">\{escape_html(post.title)}</a></h1>\{render_tag_list(post)}<p>\{escape_html(post.description)}</p></article></li>",
    )
  }
  "<ul class=\"item-list\">\{items.join("")}</ul>"
}

///|
fn render_profile_links(config : SiteConfig) -> String {
  "<div class=\"profile-links\"><a class=\"icon-link\" href=\"\{config.x_url}\" aria-label=\"X\"><img src=\"/images/x.svg\" width=\"18\" height=\"18\"/></a><a class=\"icon-link\" href=\"\{config.github_url}\" aria-label=\"GitHub\"><img src=\"/images/github.svg\" width=\"18\" height=\"18\"/></a></div>"
}

///|
/// Renders the site root with all posts sorted by descending date.
pub fn render_index_page(config : SiteConfig, site : SiteContent) -> String {
  let content = "<div class=\"wrapper\">\{render_profile_links(config)}<h2>Articles</h2>\{render_item_list(site.posts_by_descending_date())}</div>"
  render_document(
    config,
    "/",
    site.index_title,
    config.description,
    content,
    false,
    None,
    true,
  )
}

///|
/// Renders the section using its original filename order, like the current pipeline.
pub fn render_section_page(config : SiteConfig, site : SiteContent) -> String {
  let content = "<div class=\"wrapper\"><h1>\{escape_html(site.section_title)}</h1>\{render_item_list(site.posts)}</div>"
  render_document(
    config,
    "/posts",
    site.section_title,
    config.description,
    content,
    false,
    None,
    true,
  )
}

///|
/// Renders one post detail page.
pub fn render_post_page(config : SiteConfig, post : Post) -> String {
  let content = "<div class=\"wrapper\"><article><header class=\"article-header\"><h1>\{escape_html(post.title)}</h1><div class=\"article-meta\"><span>\{post.date_day()}</span></div></header><div class=\"content\">\{post.body_html}</div>\{render_tag_list(post)}</article></div>"
  render_document(
    config,
    post.path(),
    post.title,
    post.description,
    content,
    true,
    post.image_path,
    false,
  )
}

///|
/// Renders the page that links to every tag.
pub fn render_tag_list_page(config : SiteConfig, site : SiteContent) -> String {
  let tags : Array[String] = []
  for tag in site.all_tags() {
    tags.push(
      "<li class=\"tag\"><a href=\"/tags/\{tag}\">\{escape_html(tag)}</a></li>",
    )
  }
  let content = "<div class=\"wrapper\"><h1>Browse all tags</h1><ul class=\"all-tags\">\{tags.join("")}</ul></div>"
  render_document(
    config,
    "/tags",
    "",
    config.description,
    content,
    false,
    None,
    true,
  )
}

///|
/// Renders posts for one tag in descending date order.
pub fn render_tag_details_page(
  config : SiteConfig,
  site : SiteContent,
  tag : String,
) -> String {
  let content = "<div class=\"wrapper\"><h1>Tagged with <span class=\"tag\">\{escape_html(tag)}</span></h1><a class=\"browse-all\" href=\"/tags\">Browse all tags</a>\{render_item_list(site.posts_tagged_with(tag))}</div>"
  render_document(
    config,
    "/tags/\{tag}",
    "",
    config.description,
    content,
    false,
    None,
    true,
  )
}
