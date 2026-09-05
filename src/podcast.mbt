///|
/// Author and owner information embedded in a podcast feed.
pub(all) struct PodcastAuthor {
  name : String
  email_address : String
} derive(Eq, Debug)

///|
pub(all) enum PodcastType {
  Episodic
  Serial
} derive(Eq, Debug)

///|
/// Configuration equivalent to Publish's PodcastFeedConfiguration.
pub(all) struct PodcastFeedConfiguration {
  target_path : String
  ttl : Int
  maximum_item_count : Int
  podcast_type : PodcastType
  image_url : String
  copyright_text : String
  author : PodcastAuthor
  description : String
  subtitle : String
  is_explicit : Bool
  category : String
  subcategory : String?
  new_feed_url : String?
} derive(Eq, Debug)

///|
fn podcast_type_text(podcast_type : PodcastType) -> String {
  match podcast_type {
    Episodic => "episodic"
    Serial => "serial"
  }
}

///|
fn podcast_explicit_text(is_explicit : Bool) -> String {
  if is_explicit {
    "yes"
  } else {
    "no"
  }
}

///|
fn podcast_metadata_bool(value : String?) -> Bool {
  match value {
    Some("true") | Some("yes") => true
    _ => false
  }
}

///|
fn podcast_optional_number(name : String, value : String?) -> String {
  match value {
    Some(value) => "<itunes:\{name}>\{xml_text(value)}</itunes:\{name}>"
    None => ""
  }
}

///|
fn podcast_category(configuration : PodcastFeedConfiguration) -> String {
  let category = xml_text(configuration.category)
  match configuration.subcategory {
    Some(subcategory) =>
      "<itunes:category text=\"\{category}\"><itunes:category text=\"\{xml_text(subcategory)}\"/></itunes:category>"
    None => "<itunes:category text=\"\{category}\"/>"
  }
}

///|
fn podcast_duration(duration : AudioDuration) -> String {
  "\{two_digits(duration.hours)}:\{two_digits(duration.minutes)}:\{two_digits(duration.seconds)}"
}

///|
fn podcast_item(
  site : PublishSiteConfig,
  item : PublishItem,
  build_date : BuildDate,
  configuration : PodcastFeedConfiguration,
) -> Result[String, String] {
  let audio = match item.content.audio {
    Some(audio) => audio
    None => return Err("\{item.path()}: missing podcast audio")
  }
  let duration = match audio.duration {
    Some(duration) => duration
    None => return Err("\{item.path()}: missing podcast audio duration")
  }
  let byte_size = match audio.byte_size {
    Some(byte_size) => byte_size
    None => return Err("\{item.path()}: missing podcast audio size")
  }
  let title = item.rss_title()
  let description = item.content.description
  let item_url = publish_absolute_url(site, item.path())
  let explicit = podcast_metadata_bool(item.metadata.get("podcast.explicit"))
  let episode = podcast_optional_number(
    "episode",
    item.metadata.get("podcast.episode"),
  )
  let season = podcast_optional_number(
    "season",
    item.metadata.get("podcast.season"),
  )
  let mime_type = "audio/\{audio.format}"
  Ok(
    "<item>\{generic_rss_guid(site, item)}<title>\{xml_text(title)}</title><itunes:title>\{xml_text(title)}</itunes:title><description>\{xml_text(description)}</description><link>\{item_url}</link><pubDate>\{rfc822_date(generic_content_date(item.content.date, build_date.utc_offset))}</pubDate><content:encoded><![CDATA[\{generic_rss_body(site, item)}]]></content:encoded><itunes:author>\{xml_text(configuration.author.name)}</itunes:author><itunes:subtitle>\{xml_text(description)}</itunes:subtitle><itunes:summary>\{xml_text(description)}</itunes:summary><itunes:explicit>\{podcast_explicit_text(explicit)}</itunes:explicit><itunes:duration>\{podcast_duration(duration)}</itunes:duration><itunes:image href=\"\{xml_text(configuration.image_url)}\"/>\{episode}\{season}<enclosure url=\"\{xml_text(audio.url)}\" length=\"\{byte_size}\" type=\"\{mime_type}\"/><media:content url=\"\{xml_text(audio.url)}\" length=\"\{byte_size}\" type=\"\{mime_type}\" isDefault=\"true\" medium=\"audio\"><media:title type=\"plain\">\{xml_text(title)}</media:title></media:content></item>",
  )
}

///|
/// Renders an Apple Podcasts-compatible feed for one section.
pub fn render_publish_podcast_feed(
  site : PublishSiteConfig,
  content : PublishedContent,
  section_id : String,
  build_date : BuildDate,
  configuration : PodcastFeedConfiguration,
  item_predicate? : (PublishItem) -> Bool,
) -> Result[String, String] {
  let section = match
    content.sections.iter().find_first(fn(section) { section.id == section_id }) {
    Some(section) => section
    None => return Err("unknown podcast section: \{section_id}")
  }
  let items = section.items.filter(fn(item) {
    match item_predicate {
      Some(matches) => matches(item)
      None => true
    }
  })
  items.sort_by(fn(left, right) {
    right.content.date.compare(left.content.date)
  })
  let count = if items.length() < configuration.maximum_item_count {
    items.length()
  } else {
    configuration.maximum_item_count
  }
  let rendered_items : Array[String] = []
  for index = 0; index < count; index = index + 1 {
    match podcast_item(site, items[index], build_date, configuration) {
      Ok(item) => rendered_items.push(item)
      Err(error) => return Err(error)
    }
  }
  let built = rfc822_date(build_date)
  let new_feed = match configuration.new_feed_url {
    Some(url) => "<itunes:new-feed-url>\{xml_text(url)}</itunes:new-feed-url>"
    None => ""
  }
  let section_url = publish_absolute_url(site, section.id)
  let feed_url = publish_absolute_url(site, configuration.target_path)
  Ok(
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?><rss version=\"2.0\" xmlns:atom=\"http://www.w3.org/2005/Atom\" xmlns:content=\"http://purl.org/rss/1.0/modules/content/\" xmlns:itunes=\"http://www.itunes.com/dtds/podcast-1.0.dtd\" xmlns:media=\"http://www.rssboard.org/media-rss\"><channel>\{new_feed}<title>\{xml_text(site.name)}</title><description>\{xml_text(configuration.description)}</description><link>\{section_url}</link><language>\{site.language}</language><lastBuildDate>\{built}</lastBuildDate><pubDate>\{built}</pubDate><ttl>\{configuration.ttl}</ttl><atom:link href=\"\{feed_url}\" rel=\"self\" type=\"application/rss+xml\"/><copyright>\{xml_text(configuration.copyright_text)}</copyright><itunes:author>\{xml_text(configuration.author.name)}</itunes:author><itunes:subtitle>\{xml_text(configuration.subtitle)}</itunes:subtitle><itunes:summary>\{xml_text(configuration.description)}</itunes:summary><itunes:explicit>\{podcast_explicit_text(configuration.is_explicit)}</itunes:explicit><itunes:owner><itunes:name>\{xml_text(configuration.author.name)}</itunes:name><itunes:email>\{xml_text(configuration.author.email_address)}</itunes:email></itunes:owner>\{podcast_category(configuration)}<itunes:type>\{podcast_type_text(configuration.podcast_type)}</itunes:type><itunes:image href=\"\{xml_text(configuration.image_url)}\"/>\{rendered_items.join("")}</channel></rss>",
  )
}
