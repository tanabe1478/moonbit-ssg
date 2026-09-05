///|
/// Publish's two output layouts for items, pages, and tag details.
pub(all) enum HTMLFileMode {
  StandAloneFiles
  FoldersAndIndexFiles
} derive(Eq, Debug)

///|
/// Callback-based equivalent of Publish's HTMLFactory protocol.
pub(all) struct PublishHTMLFactory {
  make_index : (LocationContent, PublishedContent) -> String
  make_section : (PublishSection, PublishedContent) -> String
  make_item : (PublishItem, PublishedContent) -> String
  make_page : (PublishPage, PublishedContent) -> String
  make_tag_list : (Array[String], PublishedContent) -> String?
  make_tag_details : (String, Array[PublishItem], PublishedContent) -> String?
}

///|
fn trim_path_slashes(path : String) -> String {
  path.trim(chars=['/']).to_owned()
}

///|
fn html_output_path(path : String, file_mode : HTMLFileMode) -> String {
  let path = trim_path_slashes(path)
  match file_mode {
    FoldersAndIndexFiles => join_path(path, "index.html")
    StandAloneFiles => "\{path}.html"
  }
}

///|
fn normalized_tag_path(tag : String) -> String {
  let output = StringBuilder()
  let mut needs_separator = false
  for character in tag.trim().to_lower() {
    if character == ' ' || character == '/' {
      needs_separator = !output.is_empty()
    } else {
      if needs_separator {
        output.write_char('-')
        needs_separator = false
      }
      output.write_char(character)
    }
  }
  output.to_string()
}

///|
/// Generates HTML for every Publish location using caller-provided theme
/// callbacks. Section indexes always use folders, matching Publish 0.9.
pub fn generate_publish_html(
  output_directory : String,
  content : PublishedContent,
  factory : PublishHTMLFactory,
  file_mode? : HTMLFileMode = FoldersAndIndexFiles,
  tag_base_path? : String,
) -> Unit raise @fs.IOError {
  ensure_directory(output_directory)
  write_output_file(
    output_directory,
    "index.html",
    (factory.make_index)(content.index, content),
  )
  for section in content.sections {
    write_output_file(
      output_directory,
      join_path(trim_path_slashes(section.id), "index.html"),
      (factory.make_section)(section, content),
    )
    for item in section.items {
      write_output_file(
        output_directory,
        html_output_path(item.path(), file_mode),
        (factory.make_item)(item, content),
      )
    }
  }
  for page in content.pages {
    write_output_file(
      output_directory,
      html_output_path(page.path, file_mode),
      (factory.make_page)(page, content),
    )
  }
  match tag_base_path {
    None => ()
    Some(base_path) => {
      let tags = content.all_tags()
      match (factory.make_tag_list)(tags, content) {
        Some(html) =>
          write_output_file(
            output_directory,
            join_path(trim_path_slashes(base_path), "index.html"),
            html,
          )
        None => ()
      }
      for tag in tags {
        match
          (factory.make_tag_details)(
            tag,
            content.items_tagged_with(tag),
            content,
          ) {
          Some(html) =>
            write_output_file(
              output_directory,
              html_output_path(
                join_path(
                  trim_path_slashes(base_path),
                  normalized_tag_path(tag),
                ),
                file_mode,
              ),
              html,
            )
          None => ()
        }
      }
    }
  }
}
