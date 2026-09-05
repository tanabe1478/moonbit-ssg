///|
/// Optional Git deployment settings loaded from `site.md`.
pub(all) struct PublishProjectDeployment {
  remote : String
  branch : String
  directory : String
  commit_message : String
} derive(Eq, Debug)

///|
/// Configuration loaded from a MoonBit SSG project's `site.md`.
pub(all) struct PublishProjectConfiguration {
  site : PublishSiteConfig
  section_ids : Array[String]
  tag_base_path : String?
  output_directory : String
  deployment : PublishProjectDeployment?
} derive(Eq, Debug)

///|
fn required_project_value(
  metadata : Metadata,
  key : String,
) -> Result[String, String] {
  match metadata.get(key) {
    Some(value) if !value.is_empty() => Ok(value)
    _ => Err("site.md is missing required metadata: \{key}")
  }
}

///|
/// Parses the small, frontmatter-based project format used by the generic CLI.
pub fn parse_publish_project_configuration(
  source : String,
) -> Result[PublishProjectConfiguration, String] {
  let metadata = parse_source(source).metadata
  let url = match required_project_value(metadata, "url") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let name = match required_project_value(metadata, "name") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let section_ids = comma_separated(metadata.get("sections"))
  if section_ids.is_empty() {
    return Err("site.md must define at least one section")
  }
  let tag_base_path = match metadata.get("tagPath") {
    Some("none") => None
    Some(path) => Some(path)
    None => Some("tags")
  }
  let deployment = metadata
    .get("deploymentRemote")
    .map(fn(remote) {
      {
        remote,
        branch: metadata.get("deploymentBranch").unwrap_or("master"),
        directory: metadata.get("deploymentDirectory").unwrap_or(".publish/Git"),
        commit_message: metadata
        .get("deploymentCommitMessage")
        .unwrap_or("Publish deploy"),
      }
    })
  Ok({
    site: {
      url,
      name,
      description: metadata.get("description").unwrap_or(""),
      language: metadata.get("language").unwrap_or("en"),
      image_path: metadata.get("image"),
      favicon_path: metadata.get("favicon"),
    },
    section_ids,
    tag_base_path,
    output_directory: metadata.get("output").unwrap_or("Output"),
    deployment,
  })
}

///|
fn project_path_is_absolute(path : String) -> Bool {
  path.has_prefix("/") ||
  (path.length() >= 3 && path[1] == ':' && (path[2] == '/' || path[2] == '\\'))
}

///|
/// Resolves project-relative deployment settings into the Git helper format.
pub fn PublishProjectDeployment::git_configuration(
  self : PublishProjectDeployment,
  root_directory : String,
) -> GitDeploymentConfiguration {
  let working_directory = if project_path_is_absolute(self.directory) {
    self.directory
  } else {
    join_path(root_directory, self.directory)
  }
  {
    remote: self.remote,
    branch: self.branch,
    working_directory,
    commit_message: self.commit_message,
  }
}

///|
fn project_name_from_directory(directory : String) -> String {
  let name = publish_basename(directory)
  if name.is_empty() || name == "." {
    "Website"
  } else {
    name
  }
}

///|
/// Creates a ready-to-generate website project. Returns `false` rather than
/// overwriting a non-empty directory.
pub fn create_publish_project(
  directory : String,
  name? : String,
  first_post_date? : String,
) -> Bool raise @fs.IOError {
  if @fs.path_exists(directory) && !@fs.read_dir(directory).is_empty() {
    return false
  }
  ensure_directory(join_path(directory, "Content/posts"))
  ensure_directory(join_path(directory, "Resources"))
  let project_name = name.unwrap_or_else(fn() {
    project_name_from_directory(directory)
  })
  let first_post_date = first_post_date.unwrap_or_else(fn() {
    let now = current_build_date()
    "\{now.year}-\{two_digits(now.month)}-\{two_digits(now.day)} \{two_digits(now.hour)}:\{two_digits(now.minute)}"
  })
  @fs.write_string_to_file(
    join_path(directory, ".gitignore"),
    ".DS_Store\n.publish\nOutput\n",
  )
  @fs.write_string_to_file(
    join_path(directory, "site.md"),
    "---\nurl: https://your-website-url.com\nname: \{project_name}\ndescription: A description of \{project_name}\nlanguage: en\nsections: posts\nfavicon: images/favicon.png\ntagPath: tags\noutput: Output\n---",
  )
  @fs.write_string_to_file(
    join_path(directory, "Content/index.md"),
    "# Welcome to \{project_name}!",
  )
  @fs.write_string_to_file(
    join_path(directory, "Content/posts/index.md"),
    "# My posts",
  )
  @fs.write_string_to_file(
    join_path(directory, "Content/posts/first-post.md"),
    "---\ndate: \{first_post_date}\ndescription: A description of my first post.\ntags: first, article\n---\n# My first post\n\nMy first post's text.",
  )
  true
}

///|
fn build_publish_project_inner(
  root_directory : String,
  build_date : BuildDate,
) -> Result[String, String] raise @fs.IOError {
  let configuration = match
    parse_publish_project_configuration(
      @fs.read_file_to_string(join_path(root_directory, "site.md")),
    ) {
    Ok(configuration) => configuration
    Err(error) => return Err(error)
  }
  let content = load_published_content(
    join_path(root_directory, "Content"),
    configuration.section_ids,
  )
  let output_directory = join_path(
    root_directory,
    configuration.output_directory,
  )
  remove_tree(output_directory)
  ensure_directory(output_directory)
  let resources = join_path(root_directory, "Resources")
  if @fs.path_exists(resources) {
    copy_publish_files(resources, output_directory)
  }
  let foundation_configuration = {
    tag_base_path: configuration.tag_base_path.unwrap_or("tags"),
    stylesheet_paths: ["/styles.css"],
    feed_path: Some("/feed.rss"),
  }
  generate_publish_html(
    output_directory,
    content,
    foundation_html_factory(
      configuration.site,
      configuration=foundation_configuration,
    ),
    tag_base_path?=configuration.tag_base_path,
  )
  write_foundation_stylesheet(output_directory)
  let feed = match
    render_cached_publish_rss_feed(
      root_directory,
      configuration.site,
      content,
      configuration.section_ids,
      build_date,
    ) {
    Ok(feed) => feed
    Err(error) => return Err(error)
  }
  write_output_file(output_directory, "feed.rss", feed.value)
  write_output_file(
    output_directory,
    "sitemap.xml",
    render_publish_sitemap(configuration.site, content, build_date),
  )
  Ok(output_directory)
}

///|
/// Generates a generic project and returns its output path.
pub fn build_publish_project(
  root_directory : String,
  build_date? : BuildDate,
) -> Result[String, String] {
  let build_date = build_date.unwrap_or_else(current_build_date)
  build_publish_project_inner(root_directory, build_date) catch {
    @fs.IOError(message) => Err(message)
  }
}
