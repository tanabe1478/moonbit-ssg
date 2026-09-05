///|
fn fail(message : String) -> Unit {
  @fs.write_string_to_file("/dev/stderr", "moonbit-ssg: \{message}\n") catch {
    _ => ()
  }
  @sys.exit(1)
}

///|
fn print_help() -> Unit {
  println(
    (
      #|moonbit-ssg
      #|
      #|Commands:
      #|  new [DIRECTORY] [NAME]       Create a Foundation website project
      #|  generate [ROOT] [BUILD_DATE] Generate the current generic project
      #|  render-markdown INPUT        Render one Markdown file
      #|  build CONTENT RESOURCES OUTPUT [BUILD_DATE]
      #|                               Build the tanabe1478/blog-compatible site
    ),
  )
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
fn create_project(directory : String, name : String?) -> Unit {
  let created = @ssg.create_publish_project(directory, name?) catch {
    @fs.IOError(message) => {
      fail("unable to create project: \{message}")
      return
    }
  }
  if !created {
    fail("new project directory must be empty: \{directory}")
    return
  }
  println("Generated website project at \{directory}")
}

///|
fn generate_project(root : String, build_date : @ssg.BuildDate?) -> Unit {
  match @ssg.build_publish_project(root, build_date?) {
    Ok(output) => println("Generated site at \{output}")
    Err(error) => fail("unable to generate site: \{error}")
  }
}

///|
fn parsed_build_date(value : String) -> @ssg.BuildDate {
  match @ssg.BuildDate::parse(value) {
    Some(date) => date
    None => {
      fail("build date must use yyyy-MM-ddTHH:mm:ss with optional +HHMM")
      return @ssg.BuildDate::parse("1970-01-01T00:00:00+0000").unwrap()
    }
  }
}

///|
fn main {
  let args = @env.args()
  if args.length() == 1 {
    print_help()
    return
  }
  if args[1] == "new" && args.length() >= 2 && args.length() <= 4 {
    let directory = if args.length() >= 3 { args[2] } else { "." }
    let name = if args.length() == 4 { Some(args[3]) } else { None }
    create_project(directory, name)
    return
  }
  if args[1] == "generate" && args.length() >= 2 && args.length() <= 4 {
    let root = if args.length() >= 3 { args[2] } else { "." }
    let build_date = if args.length() == 4 {
      Some(parsed_build_date(args[3]))
    } else {
      None
    }
    generate_project(root, build_date)
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
    build_site(args[2], args[3], args[4], Some(parsed_build_date(args[5])))
    return
  }
  print_help()
  fail("unknown command or invalid arguments")
}
