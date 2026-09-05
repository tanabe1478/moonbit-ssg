///|
/// Raw key-value metadata parsed from an Ink-compatible frontmatter block.
pub(all) struct Metadata {
  entries : Array[(String, String)]
} derive(Eq, Debug)

///|
pub fn Metadata::empty() -> Metadata {
  { entries: [], }
}

///|
/// Looks up a metadata value by key.
pub fn Metadata::get(self : Metadata, key : String) -> String? {
  for entry in self.entries {
    if entry.0 == key {
      return Some(entry.1)
    }
  }
  None
}

///|
/// Metadata fields used by the current Publish blog.
pub(all) struct ItemMetadata {
  title : String?
  description : String
  date : String?
  tags : Array[String]
  image : String?
} derive(Eq, Debug)

///|
/// A Markdown source split into frontmatter and body.
pub(all) struct SourceDocument {
  metadata : Metadata
  item : ItemMetadata
  markdown : String
} derive(Eq, Debug)

///|
fn set_entry(
  entries : Array[(String, String)],
  key : String,
  value : String,
) -> Int {
  for index = 0; index < entries.length(); index = index + 1 {
    if entries[index].0 == key {
      entries[index] = (key, value)
      return index
    }
  }
  entries.push((key, value))
  entries.length() - 1
}

///|
fn parse_metadata_lines(lines : Array[String]) -> Metadata {
  let entries : Array[(String, String)] = []
  let mut last_entry : Int? = None
  for line in lines {
    let trimmed = line.trim().to_owned()
    if trimmed.is_empty() {
      continue
    }
    match trimmed.split_once(":") {
      Some((raw_key, raw_value)) => {
        let key = raw_key.trim().to_owned()
        let value = raw_value.trim().to_owned()
        if !value.is_empty() {
          last_entry = Some(set_entry(entries, key, value))
        }
      }
      None =>
        match last_entry {
          Some(index) => {
            let (key, value) = entries[index]
            entries[index] = (key, "\{value} \{trimmed}")
          }
          None => ()
        }
    }
  }
  { entries, }
}

///|
fn comma_separated(value : String?) -> Array[String] {
  match value {
    None => []
    Some(value) =>
      value
      .split(",")
      .map(fn(part) { part.trim().to_owned() })
      .filter(fn(part) { !part.is_empty() })
      .to_array()
  }
}

///|
fn item_metadata(metadata : Metadata) -> ItemMetadata {
  {
    title: metadata.get("title"),
    description: metadata.get("description").unwrap_or(""),
    date: metadata.get("date"),
    tags: comma_separated(metadata.get("tags")),
    image: metadata.get("image"),
  }
}

///|
/// Parses the metadata syntax used by Ink and Swift Publish.
///
/// Ink ignores leading whitespace before a frontmatter block. A malformed or
/// unterminated block is treated as ordinary Markdown rather than metadata.
pub fn parse_source(source : String) -> SourceDocument {
  let candidate = source.trim_start().to_owned()
  let lines = candidate.split("\n").map(fn(line) { line.to_owned() }).to_array()
  if lines.is_empty() || lines[0] != "---" {
    let metadata = Metadata::empty()
    return { metadata, item: item_metadata(metadata), markdown: source, }
  }

  let mut closing_line : Int? = None
  for index = 1; index < lines.length(); index = index + 1 {
    if lines[index].trim() == "---" {
      closing_line = Some(index)
      break
    }
  }

  match closing_line {
    None => {
      let metadata = Metadata::empty()
      { metadata, item: item_metadata(metadata), markdown: source, }
    }
    Some(index) => {
      let metadata_lines = lines[1:index]
        .iter()
        .map(fn(line) { line })
        .to_array()
      let body = lines[index + 1:].iter().map(fn(line) { line }).to_array()
      let metadata = parse_metadata_lines(metadata_lines)
      { metadata, item: item_metadata(metadata), markdown: body.join("\n"), }
    }
  }
}
