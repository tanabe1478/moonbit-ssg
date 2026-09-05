///|
fn fail(message : String) -> Unit {
  @fs.write_string_to_file("/dev/stderr", "moonbit-ssg: \{message}\n") catch {
    _ => ()
  }
  @sys.exit(1)
}

///|
fn blog_config() -> @ssg.SiteConfig {
  {
    url: "https://tanabe1478.github.io",
    name: "tanabe1478",
    description: "t__nabe1478のブログです。務め先のブログには書く程でないプログラミングに関することや私事について書きます。",
    language: "en",
    image_path: "/images/logo.png",
    favicon_path: "/images/favicon.png",
    stylesheet_path: "/styles.css",
    feed_path: "/feed.rss",
    analytics_id: "G-Q9KK5M4YNY",
    x_url: "https://x.com/t__nabe1478",
    github_url: "https://github.com/tanabe1478",
  }
}

///|
fn render_markdown_file(path : String) -> Unit {
  let source = @fs.read_file_to_string(path) catch {
    @fs.IOError(message) => {
      fail("unable to read \{path}: \{message}")
      return
    }
  }
  println(@ssg.render_markdown(@ssg.parse_source(source).markdown))
}

///|
fn build_site(
  content : String,
  resources : String,
  output : String,
  build_date : @ssg.BuildDate?,
) -> Unit {
  @ssg.write_site_output(blog_config(), content, resources, output, build_date?) catch {
    @fs.IOError(message) => {
      fail("unable to build site: \{message}")
      return
    }
  }
  println("Generated site at \{output}")
}

///|
fn main {
  let args = @env.args()
  if args.length() == 1 {
    println(@ssg.banner())
    return
  }
  if args.length() == 3 && args[1] == "render-markdown" {
    render_markdown_file(args[2])
    return
  }
  if args.length() == 5 && args[1] == "build" {
    build_site(args[2], args[3], args[4], None)
    return
  }
  if args.length() == 6 && args[1] == "build" {
    match @ssg.BuildDate::parse(args[5]) {
      Some(date) => build_site(args[2], args[3], args[4], Some(date))
      None => fail("build date must use yyyy-MM-ddTHH:mm:ss")
    }
    return
  }
  fail(
    "usage: moonbit-ssg [render-markdown INPUT | build CONTENT RESOURCES OUTPUT [BUILD_DATE]]",
  )
}
