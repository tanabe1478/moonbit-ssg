///|
pub(all) struct FoundationThemeConfiguration {
  tag_base_path : String
  stylesheet_paths : Array[String]
  feed_path : String?
} derive(Eq, Debug)

///|
pub fn default_foundation_theme_configuration() -> FoundationThemeConfiguration {
  {
    tag_base_path: "tags",
    stylesheet_paths: ["/styles.css"],
    feed_path: Some("/feed.rss"),
  }
}

///|
fn foundation_page_title(
  site : PublishSiteConfig,
  content : LocationContent,
) -> String {
  if content.title.is_empty() {
    site.name
  } else {
    "\{content.title} | \{site.name}"
  }
}

///|
fn foundation_head(
  site : PublishSiteConfig,
  content : LocationContent,
  path : String,
  configuration : FoundationThemeConfiguration,
) -> String {
  let url = publish_absolute_url(site, path)
  let title = foundation_page_title(site, content)
  let description = if content.description.is_empty() {
    site.description
  } else {
    content.description
  }
  let styles = configuration.stylesheet_paths
    .map(fn(path) {
      "<link rel=\"stylesheet\" href=\"\{xml_text(publish_absolute_path(path))}\" type=\"text/css\"/>"
    })
    .join("")
  let favicon = match site.favicon_path {
    Some(path) => render_publish_favicon({ path, mime_type: "image/png", })
    None => ""
  }
  let feed = match configuration.feed_path {
    Some(path) =>
      "<link rel=\"alternate\" href=\"\{xml_text(publish_absolute_path(path))}\" type=\"application/rss+xml\" title=\"Subscribe to \{xml_text(site.name)}\"/>"
    None => ""
  }
  let image_path = match content.image_path {
    Some(path) => Some(path)
    None => site.image_path
  }
  let images = match image_path {
    Some(path) => {
      let image_url = publish_absolute_url(site, path)
      "<meta name=\"twitter:image\" content=\"\{xml_text(image_url)}\"/><meta name=\"og:image\" content=\"\{xml_text(image_url)}\"/>"
    }
    None => ""
  }
  let card = match content.image_path {
    Some(_) => "summary_large_image"
    None => "summary"
  }
  "<head><meta charset=\"UTF-8\"/><meta name=\"og:site_name\" content=\"\{xml_text(site.name)}\"/><link rel=\"canonical\" href=\"\{xml_text(url)}\"/><meta name=\"twitter:url\" content=\"\{xml_text(url)}\"/><meta name=\"og:url\" content=\"\{xml_text(url)}\"/><title>\{xml_text(title)}</title><meta name=\"twitter:title\" content=\"\{xml_text(title)}\"/><meta name=\"og:title\" content=\"\{xml_text(title)}\"/><meta name=\"description\" content=\"\{xml_text(description)}\"/><meta name=\"twitter:description\" content=\"\{xml_text(description)}\"/><meta name=\"og:description\" content=\"\{xml_text(description)}\"/><meta name=\"twitter:card\" content=\"\{card}\"/>\{styles}<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\"/>\{favicon}\{feed}\{images}</head>"
}

///|
fn foundation_header(
  site : PublishSiteConfig,
  content : PublishedContent,
  selected_section : String?,
) -> String {
  let navigation = if content.sections.length() > 1 {
    let links = content.sections
      .map(fn(section) {
        let selected = if Some(section.id) == selected_section {
          " class=\"selected\""
        } else {
          ""
        }
        "<li><a\{selected} href=\"/\{xml_text(section.id)}\">\{xml_text(section.content.title)}</a></li>"
      })
      .join("")
    "<nav><ul>\{links}</ul></nav>"
  } else {
    ""
  }
  "<header><div class=\"wrapper\"><a class=\"site-name\" href=\"/\">\{xml_text(site.name)}</a>\{navigation}</div></header>"
}

///|
fn foundation_footer() -> String {
  "<footer><p>Generated using <a href=\"https://github.com/johnsundell/publish\">Publish</a></p><p><a href=\"/feed.rss\">RSS feed</a></p></footer>"
}

///|
fn foundation_document(
  site : PublishSiteConfig,
  all_content : PublishedContent,
  content : LocationContent,
  path : String,
  body : String,
  selected_section : String?,
  item_page : Bool,
  configuration : FoundationThemeConfiguration,
) -> String {
  let body_class = if item_page { " class=\"item-page\"" } else { "" }
  "<!DOCTYPE html><html lang=\"\{site.language}\">\{foundation_head(site, content, path, configuration)}<body\{body_class}>\{foundation_header(site, all_content, selected_section)}\{body}\{foundation_footer()}</body></html>"
}

///|
fn foundation_tag_list(
  item : PublishItem,
  configuration : FoundationThemeConfiguration,
) -> String {
  let tags = item.tags
    .map(fn(tag) {
      "<li><a href=\"/\{configuration.tag_base_path}/\{normalized_tag_path(tag)}\">\{xml_text(tag)}</a></li>"
    })
    .join("")
  "<ul class=\"tag-list\">\{tags}</ul>"
}

///|
fn foundation_item_list(
  items : Array[PublishItem],
  configuration : FoundationThemeConfiguration,
) -> String {
  let rows = items
    .map(fn(item) {
      "<li><article><h1><a href=\"\{item.path()}\">\{xml_text(item.content.title)}</a></h1>\{foundation_tag_list(item, configuration)}<p>\{xml_text(item.content.description)}</p></article></li>"
    })
    .join("")
  "<ul class=\"item-list\">\{rows}</ul>"
}

///|
/// Creates the HTMLFactory used by Publish's built-in Foundation theme.
pub fn foundation_html_factory(
  site : PublishSiteConfig,
  configuration? : FoundationThemeConfiguration = default_foundation_theme_configuration(),
) -> PublishHTMLFactory {
  {
    make_index: fn(index, content) {
      let items = content.all_items()
      items.sort_by(fn(left, right) {
        right.content.date.compare(left.content.date)
      })
      let body = "<div class=\"wrapper\"><h1>\{xml_text(index.title)}</h1><p class=\"description\">\{xml_text(site.description)}</p><h2>Latest content</h2>\{foundation_item_list(items, configuration)}</div>"
      foundation_document(
        site,
        content,
        index,
        "/",
        body,
        None,
        false,
        configuration,
      )
    },
    make_section: fn(section, content) {
      let body = "<div class=\"wrapper\"><h1>\{xml_text(section.content.title)}</h1>\{foundation_item_list(section.items, configuration)}</div>"
      foundation_document(
        site,
        content,
        section.content,
        section.id,
        body,
        Some(section.id),
        false,
        configuration,
      )
    },
    make_item: fn(item, content) {
      let body = "<div class=\"wrapper\"><article><div class=\"content\">\{item.content.body_html}</div><span>Tagged with: </span>\{foundation_tag_list(item, configuration)}</article></div>"
      foundation_document(
        site,
        content,
        item.content,
        item.path(),
        body,
        Some(item.section_id),
        true,
        configuration,
      )
    },
    make_page: fn(page, content) {
      foundation_document(
        site,
        content,
        page.content,
        page.path,
        "<div class=\"wrapper\">\{page.content.body_html}</div>",
        None,
        false,
        configuration,
      )
    },
    make_tag_list: fn(tags, content) {
      let list = tags
        .map(fn(tag) {
          "<li class=\"tag\"><a href=\"/\{configuration.tag_base_path}/\{normalized_tag_path(tag)}\">\{xml_text(tag)}</a></li>"
        })
        .join("")
      let page = empty_location_content("")
      Some(
        foundation_document(
          site,
          content,
          page,
          configuration.tag_base_path,
          "<div class=\"wrapper\"><h1>Browse all tags</h1><ul class=\"all-tags\">\{list}</ul></div>",
          None,
          false,
          configuration,
        ),
      )
    },
    make_tag_details: fn(tag, items, content) {
      let page = empty_location_content("")
      Some(
        foundation_document(
          site,
          content,
          page,
          "\{configuration.tag_base_path}/\{normalized_tag_path(tag)}",
          "<div class=\"wrapper\"><h1>Tagged with <span class=\"tag\">\{xml_text(tag)}</span></h1><a class=\"browse-all\" href=\"/\{configuration.tag_base_path}\">Browse all tags</a>\{foundation_item_list(items, configuration)}</div>",
          None,
          false,
          configuration,
        ),
      )
    },
  }
}
