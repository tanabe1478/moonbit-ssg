///|
fn parent_directory(path : String) -> String {
  let characters = path.to_array()
  let mut separator = -1
  for index = 0; index < characters.length(); index = index + 1 {
    if characters[index] == '/' {
      separator = index
    }
  }
  if separator < 0 {
    ""
  } else if separator == 0 {
    "/"
  } else {
    let output = StringBuilder()
    for index = 0; index < separator; index = index + 1 {
      output.write_char(characters[index])
    }
    output.to_string()
  }
}

///|
fn ensure_directory(path : String) -> Unit raise @fs.IOError {
  if path.is_empty() || @fs.path_exists(path) {
    return
  }
  let parent = parent_directory(path)
  if !parent.is_empty() && parent != path {
    ensure_directory(parent)
  }
  @fs.create_dir(path)
}

///|
fn remove_tree(path : String) -> Unit raise @fs.IOError {
  if !@fs.path_exists(path) {
    return
  }
  if @fs.is_dir(path) {
    let names = @fs.read_dir(path)
    for name in names {
      remove_tree(join_path(path, name))
    }
    @fs.remove_dir(path)
  } else {
    @fs.remove_file(path)
  }
}

///|
fn copy_tree(source : String, destination : String) -> Unit raise @fs.IOError {
  if @fs.is_dir(source) {
    ensure_directory(destination)
    let names = @fs.read_dir(source)
    for name in names {
      copy_tree(join_path(source, name), join_path(destination, name))
    }
  } else {
    ensure_directory(parent_directory(destination))
    @fs.write_bytes_to_file(destination, @fs.read_file_to_bytes(source))
  }
}

///|
fn write_output_file(
  output_directory : String,
  relative_path : String,
  content : String,
) -> Unit raise @fs.IOError {
  let destination = join_path(output_directory, relative_path)
  ensure_directory(parent_directory(destination))
  @fs.write_string_to_file(destination, content)
}

///|
fn filesystem_tag_name(tag : String) -> String {
  // Foundation writes decomposed filenames on macOS. The current site's only
  // precomposed kana tag needs the same on-disk representation for parity.
  tag.replace_all(old="ゲ", new="ゲ")
}

///|
/// Generates HTML pages and copies Publish resources into a clean output tree.
pub fn write_site_output(
  config : SiteConfig,
  content_directory : String,
  resources_directory : String,
  output_directory : String,
  theme_stylesheet? : String = "MyHtmlTheme/styles.css",
) -> Unit raise @fs.IOError {
  let site = load_site_content(content_directory)
  remove_tree(output_directory)
  ensure_directory(output_directory)
  write_output_file(
    output_directory,
    "index.html",
    render_index_page(config, site),
  )
  write_output_file(
    output_directory,
    "posts/index.html",
    render_section_page(config, site),
  )
  for post in site.posts {
    write_output_file(
      output_directory,
      "posts/\{post.slug}/index.html",
      render_post_page(config, post),
    )
  }
  write_output_file(
    output_directory,
    "tags/index.html",
    render_tag_list_page(config, site),
  )
  for tag in site.all_tags() {
    write_output_file(
      output_directory,
      "tags/\{filesystem_tag_name(tag)}/index.html",
      render_tag_details_page(config, site, tag),
    )
  }
  copy_tree(resources_directory, output_directory)
  copy_tree(
    join_path(resources_directory, theme_stylesheet),
    join_path(output_directory, "styles.css"),
  )
}
