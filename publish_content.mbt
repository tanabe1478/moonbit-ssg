///|
/// A duration accepted by Publish's audio metadata.
pub(all) struct AudioDuration {
  hours : Int
  minutes : Int
  seconds : Int
} derive(Eq, Debug)

///|
/// Audio metadata used by podcast feeds and HTML players.
pub(all) struct Audio {
  url : String
  format : String
  duration : AudioDuration?
  byte_size : Int?
} derive(Eq, Debug)

///|
/// The three video sources represented by Publish.
pub(all) enum Video {
  Hosted(url~ : String, format~ : String)
  YouTube(id~ : String)
  Vimeo(id~ : String)
} derive(Eq, Debug)

///|
/// Per-item overrides used while generating RSS feeds.
pub(all) struct RSSItemProperties {
  guid : String?
  title_prefix : String?
  title_suffix : String?
  body_prefix : String?
  body_suffix : String?
  link : String?
} derive(Eq, Debug)

///|
/// The fields shared by Publish's index, sections, items, and pages.
pub(all) struct LocationContent {
  title : String
  description : String
  body_html : String
  date : String
  last_modified : String
  image_path : String?
  audio : Audio?
  video : Video?
} derive(Eq, Debug)

///|
/// An item contained by a section. Custom metadata is kept without imposing a
/// site-specific schema, which is the dynamic equivalent of ItemMetadata.
pub(all) struct PublishItem {
  section_id : String
  relative_path : String
  metadata : Metadata
  tags : Array[String]
  content : LocationContent
  rss : RSSItemProperties
} derive(Eq, Debug)

///|
/// A free-form page loaded from a root Markdown file or a non-section folder.
pub(all) struct PublishPage {
  path : String
  content : LocationContent
} derive(Eq, Debug)

///|
/// A named collection of items and its optional index content.
pub(all) struct PublishSection {
  id : String
  content : LocationContent
  items : Array[PublishItem]
} derive(Eq, Debug)

///|
/// Publish's complete in-memory website model.
pub(all) struct PublishedContent {
  index : LocationContent
  sections : Array[PublishSection]
  pages : Array[PublishPage]
} derive(Eq, Debug)

///|
/// Source input for a generic section.
pub(all) struct PublishSectionSource {
  id : String
  index_source : String?
  items : Array[PostSource]
} derive(Eq, Debug)

///|
/// Source input for a free-form page.
pub(all) struct PublishPageSource {
  path : String
  source : String
} derive(Eq, Debug)

///|
fn parse_audio_duration(value : String?) -> AudioDuration? {
  let value = match value {
    Some(value) => value
    None => return None
  }
  let components = value.split(":").to_array()
  if components.length() < 1 || components.length() > 3 {
    return None
  }
  let numbers : Array[Int] = []
  for component in components {
    match parse_number(component) {
      Some(number) => numbers.push(number)
      None => return None
    }
  }
  if numbers.length() == 1 {
    Some({ hours: 0, minutes: 0, seconds: numbers[0], })
  } else if numbers.length() == 2 {
    Some({ hours: 0, minutes: numbers[0], seconds: numbers[1], })
  } else {
    Some({ hours: numbers[0], minutes: numbers[1], seconds: numbers[2], })
  }
}

///|
fn parse_audio(metadata : Metadata) -> Audio? {
  let url = match metadata.get("audio.url") {
    Some(url) => url
    None => return None
  }
  Some({
    url,
    format: metadata.get("audio.format").unwrap_or("mp3"),
    duration: parse_audio_duration(metadata.get("audio.duration")),
    byte_size: match metadata.get("audio.size") {
      Some(size) => parse_number(size)
      None => None
    },
  })
}

///|
fn parse_video(metadata : Metadata) -> Video? {
  match metadata.get("video.youTube") {
    Some(id) => return Some(YouTube(id~))
    None => ()
  }
  match metadata.get("video.vimeo") {
    Some(id) => return Some(Vimeo(id~))
    None => ()
  }
  match metadata.get("video.url") {
    Some(url) =>
      Some(Hosted(url~, format=metadata.get("video.format").unwrap_or("mp4")))
    None => None
  }
}

///|
fn location_content(
  document : SourceDocument,
  fallback : String,
) -> LocationContent {
  let metadata = document.metadata
  let date = metadata.get("date").unwrap_or("")
  {
    title: metadata
    .get("title")
    .unwrap_or_else(fn() {
      markdown_title(document.markdown).unwrap_or(fallback)
    }),
    description: metadata.get("description").unwrap_or(""),
    body_html: render_markdown(document.markdown),
    date,
    last_modified: metadata.get("lastModified").unwrap_or(date),
    image_path: metadata.get("image"),
    audio: parse_audio(metadata),
    video: parse_video(metadata),
  }
}

///|
fn rss_item_properties(metadata : Metadata) -> RSSItemProperties {
  {
    guid: metadata.get("rss.guid"),
    title_prefix: metadata.get("rss.titlePrefix"),
    title_suffix: metadata.get("rss.titleSuffix"),
    body_prefix: metadata.get("rss.bodyPrefix"),
    body_suffix: metadata.get("rss.bodySuffix"),
    link: metadata.get("rss.link"),
  }
}

///|
/// Builds an item while honoring Publish's optional `path` override.
pub fn build_publish_item(
  section_id : String,
  source_path : String,
  source : String,
) -> PublishItem {
  let document = parse_source(source)
  {
    section_id,
    relative_path: document.metadata.get("path").unwrap_or(source_path),
    metadata: document.metadata,
    tags: document.item.tags,
    content: location_content(document, source_path),
    rss: rss_item_properties(document.metadata),
  }
}

///|
/// Builds a free-form page from Markdown.
pub fn build_publish_page(path : String, source : String) -> PublishPage {
  { path, content: location_content(parse_source(source), path), }
}

///|
fn empty_location_content(fallback : String) -> LocationContent {
  {
    title: fallback,
    description: "",
    body_html: "",
    date: "",
    last_modified: "",
    image_path: None,
    audio: None,
    video: None,
  }
}

///|
/// Builds a complete multi-section Publish content model without file I/O.
pub fn build_published_content(
  index_source : String,
  section_sources : Array[PublishSectionSource],
  page_sources : Array[PublishPageSource],
) -> PublishedContent {
  let sections = section_sources.map(fn(section) {
    let section_content = match section.index_source {
      Some(source) => location_content(parse_source(source), section.id)
      None => empty_location_content(section.id)
    }
    {
      id: section.id,
      content: section_content,
      items: section.items.map(fn(item) {
        build_publish_item(section.id, item.slug, item.source)
      }),
    }
  })
  {
    index: location_content(parse_source(index_source), ""),
    sections,
    pages: page_sources.map(fn(page) {
      build_publish_page(page.path, page.source)
    }),
  }
}

///|
pub fn PublishItem::path(self : PublishItem) -> String {
  "/\{self.section_id}/\{self.relative_path}"
}

///|
pub fn PublishItem::rss_title(self : PublishItem) -> String {
  self.rss.title_prefix.unwrap_or("") +
  self.content.title +
  self.rss.title_suffix.unwrap_or("")
}

///|
pub fn PublishedContent::all_items(
  self : PublishedContent,
) -> Array[PublishItem] {
  let items : Array[PublishItem] = []
  for section in self.sections {
    items.push_iter(section.items.iter())
  }
  items
}

///|
pub fn PublishedContent::all_tags(self : PublishedContent) -> Array[String] {
  let tags : Array[String] = []
  for item in self.all_items() {
    for tag in item.tags {
      if !tags.contains(tag) {
        tags.push(tag)
      }
    }
  }
  tags.sort_by(compare_unicode_scalars)
  tags
}

///|
pub fn PublishedContent::items_tagged_with(
  self : PublishedContent,
  tag : String,
) -> Array[PublishItem] {
  let items = self.all_items().filter(fn(item) { item.tags.contains(tag) })
  items.sort_by(fn(left, right) {
    right.content.date.compare(left.content.date)
  })
  items
}

///|
fn publish_source_extension(name : String) -> String? {
  for extension in [".markdown", ".text", ".md", ".txt"] {
    if name.has_suffix(extension) {
      return Some(extension)
    }
  }
  None
}

///|
fn source_path_without_extension(path : String, extension : String) -> String {
  path[:path.length() - extension.length()].to_owned()
}

///|
fn collect_markdown_sources(
  directory : String,
  relative_directory : String,
  skip_root_index : Bool,
) -> Array[PostSource] raise @fs.IOError {
  let sources : Array[PostSource] = []
  let names = @fs.read_dir(directory)
  names.sort_by(compare_unicode_scalars)
  for name in names {
    let full_path = join_path(directory, name)
    let relative_path = if relative_directory.is_empty() {
      name
    } else {
      join_path(relative_directory, name)
    }
    if @fs.is_dir(full_path) {
      sources.push_iter(
        collect_markdown_sources(full_path, relative_path, false).iter(),
      )
      continue
    }
    match publish_source_extension(name) {
      None => ()
      Some(extension) => {
        let path = source_path_without_extension(relative_path, extension)
        if !(skip_root_index && path == "index") {
          sources.push({
            slug: path,
            source: @fs.read_file_to_string(full_path),
          })
        }
      }
    }
  }
  sources
}

///|
fn section_index_source(directory : String) -> String? raise @fs.IOError {
  let names = @fs.read_dir(directory)
  names.sort_by(compare_unicode_scalars)
  for name in names {
    let path = join_path(directory, name)
    if !@fs.is_dir(path) {
      match publish_source_extension(name) {
        Some(extension) =>
          if source_path_without_extension(name, extension) == "index" {
            return Some(@fs.read_file_to_string(path))
          }
        None => ()
      }
    }
  }
  None
}

///|
fn find_section_id(
  folder_name : String,
  section_ids : Array[String],
) -> String? {
  let normalized = folder_name.to_lower()
  for id in section_ids {
    if id == normalized {
      return Some(id)
    }
  }
  None
}

///|
/// Loads Publish's complete Markdown layout. Recognized root folders become
/// sections; root files and files below all other folders become pages.
pub fn load_published_content(
  content_directory : String,
  section_ids : Array[String],
) -> PublishedContent raise @fs.IOError {
  let index_path = join_path(content_directory, "index.md")
  let index_source = if @fs.path_exists(index_path) {
    @fs.read_file_to_string(index_path)
  } else {
    ""
  }
  let sections : Array[PublishSectionSource] = []
  for id in section_ids {
    sections.push({ id, index_source: None, items: [], })
  }
  let pages : Array[PublishPageSource] = []
  let names = @fs.read_dir(content_directory)
  names.sort_by(compare_unicode_scalars)
  for name in names {
    let full_path = join_path(content_directory, name)
    if @fs.is_dir(full_path) {
      match find_section_id(name, section_ids) {
        Some(id) => {
          let index_source = section_index_source(full_path)
          let items = collect_markdown_sources(full_path, "", true)
          for index = 0; index < sections.length(); index = index + 1 {
            if sections[index].id == id {
              sections[index] = { id, index_source, items, }
              break
            }
          }
        }
        None => {
          let sources = collect_markdown_sources(full_path, name, false)
          for source in sources {
            pages.push({ path: source.slug, source: source.source, })
          }
        }
      }
      continue
    }
    match publish_source_extension(name) {
      Some(extension) => {
        let path = source_path_without_extension(name, extension)
        if path != "index" {
          pages.push({ path, source: @fs.read_file_to_string(full_path), })
        }
      }
      None => ()
    }
  }
  build_published_content(index_source, sections, pages)
}
