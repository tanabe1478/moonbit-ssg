///|
/// Local build time used by Publish's RSS and sitemap generators.
pub(all) struct BuildDate {
  year : Int
  month : Int
  day : Int
  hour : Int
  minute : Int
  second : Int
  utc_offset : String
} derive(Eq, Debug)

///|
fn parse_number(value : StringView) -> Int? {
  Some(@string.parse_int(value)) catch {
    _ => None
  }
}

///|
/// Parses `yyyy-MM-ddTHH:mm:ss` with an optional `+HHMM` UTC offset.
pub fn BuildDate::parse(value : String) -> BuildDate? {
  if (value.length() != 19 && value.length() != 24) ||
    value[4] != '-' ||
    value[7] != '-' ||
    value[10] != 'T' ||
    value[13] != ':' ||
    value[16] != ':' {
    return None
  }
  match
    (
      parse_number(value[:4]),
      parse_number(value[5:7]),
      parse_number(value[8:10]),
      parse_number(value[11:13]),
      parse_number(value[14:16]),
      parse_number(value[17:19]),
    ) {
    (Some(year), Some(month), Some(day), Some(hour), Some(minute), Some(second)) => {
      let utc_offset = if value.length() == 24 {
        value[19:24].to_owned()
      } else {
        "+0900"
      }
      if utc_offset.length() != 5 ||
        (utc_offset[0] != '+' && utc_offset[0] != '-') {
        return None
      }
      Some({ year, month, day, hour, minute, second, utc_offset, })
    }
    _ => None
  }
}

///|
fn current_build_date() -> BuildDate {
  let zone = @time.fixed_zone("JST", 9 * 60 * 60) catch {
    _ => abort("unable to construct JST timezone")
  }
  let unix_seconds = (@env.now() / 1000UL).reinterpret_as_int64()
  let date = @time.unix(unix_seconds, zone~) catch {
    _ => abort("unable to read current date")
  }
  {
    year: date.year(),
    month: date.month(),
    day: date.day(),
    hour: date.hour(),
    minute: date.minute(),
    second: date.second(),
    utc_offset: "+0900",
  }
}

///|
fn weekday_index(year : Int, month : Int, day : Int) -> Int {
  let mut adjusted_year = year
  let mut adjusted_month = month
  if adjusted_month < 3 {
    adjusted_year = adjusted_year - 1
    adjusted_month = adjusted_month + 12
  }
  (
    day +
    13 * (adjusted_month + 1) / 5 +
    adjusted_year +
    adjusted_year / 4 -
    adjusted_year / 100 +
    adjusted_year / 400
  ) %
  7
}

///|
fn weekday_name(year : Int, month : Int, day : Int) -> String {
  ["Sat", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri"][weekday_index(
    year, month, day,
  )]
}

///|
fn month_name(month : Int) -> String {
  [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov",
    "Dec",
  ][month - 1]
}

///|
fn two_digits(value : Int) -> String {
  if value < 10 {
    "0\{value}"
  } else {
    value.to_string()
  }
}

///|
fn rfc822_date(date : BuildDate) -> String {
  "\{weekday_name(date.year, date.month, date.day)}, \{date.day} \{month_name(date.month)} \{date.year} \{two_digits(date.hour)}:\{two_digits(date.minute)}:\{two_digits(date.second)} \{date.utc_offset}"
}

///|
fn post_build_date(post : Post, utc_offset : String) -> BuildDate {
  let value = post.date.replace_all(old=" ", new="T") + ":00" + utc_offset
  BuildDate::parse(value).unwrap_or({
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
fn xml_text(value : String) -> String {
  escape_html(value)
}

///|
fn rss_body(config : SiteConfig, html : String) -> String {
  html
  .replace_all(old="src=\"/", new="src=\"\{config.url}/")
  .replace_all(old="href=\"/", new="href=\"\{config.url}/")
}

///|
/// Renders Publish's default RSS 2.0 feed for all posts.
pub fn render_rss_feed(
  config : SiteConfig,
  site : SiteContent,
  build_date : BuildDate,
) -> String {
  let items : Array[String] = []
  let posts = site.posts_by_descending_date()
  let count = if posts.length() < 100 { posts.length() } else { 100 }
  for index = 0; index < count; index = index + 1 {
    let post = posts[index]
    let url = absolute_url(config, post.path())
    items.push(
      "<item><guid isPermaLink=\"true\">\{url}</guid><title>\{xml_text(post.title)}</title><description>\{xml_text(post.description)}</description><link>\{url}</link><pubDate>\{rfc822_date(post_build_date(post, build_date.utc_offset))}</pubDate><content:encoded><![CDATA[\{rss_body(config, post.body_html)}]]></content:encoded></item>",
    )
  }
  let built = rfc822_date(build_date)
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?><rss version=\"2.0\" xmlns:atom=\"http://www.w3.org/2005/Atom\" xmlns:content=\"http://purl.org/rss/1.0/modules/content/\"><channel><title>\{xml_text(config.name)}</title><description>\{xml_text(config.description)}</description><link>\{config.url}</link><language>\{config.language}</language><lastBuildDate>\{built}</lastBuildDate><pubDate>\{built}</pubDate><ttl>250</ttl><atom:link href=\"\{absolute_url(config, config.feed_path)}\" rel=\"self\" type=\"application/rss+xml\"/>\{items.join("")}</channel></rss>"
}

///|
fn sitemap_entry(
  url : String,
  frequency : String,
  priority : String,
  last_modified : String,
) -> String {
  "<url><loc>\{url}</loc><changefreq>\{frequency}</changefreq><priority>\{priority}</priority><lastmod>\{last_modified}</lastmod></url>"
}

///|
/// Renders the section and its posts in the order used by Publish's sitemap.
pub fn render_sitemap(
  config : SiteConfig,
  site : SiteContent,
  build_date : BuildDate,
) -> String {
  let last_modified = "\{build_date.year}-\{two_digits(build_date.month)}-\{two_digits(build_date.day)}"
  let entries : Array[String] = [
    sitemap_entry(absolute_url(config, "/posts"), "daily", "1.0", last_modified),
  ]
  for post in site.posts_by_descending_date() {
    entries.push(
      sitemap_entry(
        absolute_url(config, post.path()),
        "monthly",
        "0.5",
        last_modified,
      ),
    )
  }
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?><urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\" xmlns:image=\"http://www.google.com/schemas/sitemap-image/1.1\">\{entries.join("")}</urlset>"
}
