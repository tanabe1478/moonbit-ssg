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
      #|  run [ROOT] [-p PORT]         Generate and serve a generic project
      #|  deploy [ROOT]                Generate and deploy a generic project
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
fn parse_port(value : String) -> Int {
  let port = Some(@string.parse_int(value)) catch { _ => None }
  match port {
    Some(port) if port > 0 && port <= 65535 => port
    _ => {
      fail("port must be an integer between 1 and 65535")
      return 8000
    }
  }
}

///|
async fn run_project(root : String, port : Int) -> Unit {
  let output = match @ssg.build_publish_project(root) {
    Ok(output) => output
    Err(error) => {
      fail("unable to generate site: \{error}")
      return
    }
  }
  println("Starting web server at http://localhost:\{port}")
  println("Press CTRL-C to stop the server")
  let status = @process.run("python3", [
    "-m",
    "http.server",
    port.to_string(),
    "--directory",
    output,
  ])
  if status != 0 {
    fail("web server exited with status \{status}")
  }
}

///|
async fn run_git_command(
  configuration : @ssg.GitDeploymentConfiguration,
  arguments : Array[String],
) -> Bool {
  @process.run("git", arguments, cwd=configuration.working_directory) == 0
}

///|
async fn require_git_command(
  configuration : @ssg.GitDeploymentConfiguration,
  arguments : Array[String],
) -> Unit {
  if !run_git_command(configuration, arguments) {
    fail("git \{arguments.join(" ")} failed")
  }
}

///|
async fn deploy_project(root : String) -> Unit {
  let output = match @ssg.build_publish_project(root) {
    Ok(output) => output
    Err(error) => {
      fail("unable to generate site: \{error}")
      return
    }
  }
  let source = @fs.read_file_to_string(
    root.trim_end(chars="/").to_owned() + "/site.md",
  ) catch {
    @fs.IOError(message) => {
      fail("unable to read deployment settings: \{message}")
      return
    }
  }
  let project = match @ssg.parse_publish_project_configuration(source) {
    Ok(project) => project
    Err(error) => {
      fail("unable to read deployment settings: \{error}")
      return
    }
  }
  let deployment = match project.deployment {
    Some(deployment) => deployment
    None => {
      fail("site.md must define deploymentRemote before deployment")
      return
    }
  }
  let configuration = deployment.git_configuration(root)
  match @ssg.ensure_git_deployment_working_directory(configuration) {
    Err(error) => {
      fail("unable to prepare deployment directory: \{error}")
      return
    }
    Ok(_) => ()
  }
  let git_directory = configuration.working_directory
    .trim_end(chars="/")
    .to_owned() +
    "/.git"
  if !@fs.path_exists(git_directory) {
    require_git_command(configuration, ["init"])
    require_git_command(configuration, [
      "remote",
      "add",
      "origin",
      configuration.remote,
    ])
  }
  require_git_command(configuration, [
    "remote",
    "set-url",
    "origin",
    configuration.remote,
  ])
  // Publish allows pull to fail so an empty remote can be deployed initially.
  ignore(
    run_git_command(configuration, ["pull", "origin", configuration.branch]),
  )
  if !run_git_command(configuration, ["checkout", configuration.branch]) {
    require_git_command(configuration, ["checkout", "-b", configuration.branch])
  }
  match @ssg.sync_git_deployment_output(output, configuration) {
    Err(error) => {
      fail("unable to copy generated output for deployment: \{error}")
      return
    }
    Ok(_) => ()
  }
  require_git_command(configuration, ["add", "."])
  require_git_command(configuration, [
    "commit",
    "-a",
    "-m",
    configuration.commit_message,
    "--allow-empty",
  ])
  require_git_command(configuration, ["push", "origin", configuration.branch])
  println("Deployed site to \{configuration.remote} on \{configuration.branch}")
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
async fn main {
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
  if args[1] == "run" {
    if args.length() == 2 {
      run_project(".", 8000)
      return
    }
    if args.length() == 3 {
      run_project(args[2], 8000)
      return
    }
    if args.length() == 4 && (args[2] == "-p" || args[2] == "--port") {
      run_project(".", parse_port(args[3]))
      return
    }
    if args.length() == 5 && (args[3] == "-p" || args[3] == "--port") {
      run_project(args[2], parse_port(args[4]))
      return
    }
  }
  if args[1] == "deploy" && (args.length() == 2 || args.length() == 3) {
    let root = if args.length() == 3 { args[2] } else { "." }
    deploy_project(root)
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
