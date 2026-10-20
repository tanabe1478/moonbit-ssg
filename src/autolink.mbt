///|
/// GFM-style extended autolinks for bare `http://`, `https://` and `www.`
/// URLs in plain text. Two deliberate differences from GFM suit Japanese
/// prose, where URLs are often written without surrounding spaces:
/// - a URL ends at the first non-ASCII character, and
/// - a URL may start right after a non-ASCII character.
let autolink_prefixes : Array[String] = ["https://", "http://", "www."]

///|
fn is_ascii_alphanumeric(character : Char) -> Bool {
  (character >= 'a' && character <= 'z') ||
  (character >= 'A' && character <= 'Z') ||
  (character >= '0' && character <= '9')
}

///|
fn is_autolink_whitespace(character : Char) -> Bool {
  character == ' ' ||
  character == '\t' ||
  character == '\n' ||
  character == '\r' ||
  character == '\u{0C}'
}

///|
fn can_start_autolink(characters : Array[Char], index : Int) -> Bool {
  if index == 0 {
    return true
  }
  let previous = characters[index - 1]
  is_autolink_whitespace(previous) ||
  previous == '*' ||
  previous == '_' ||
  previous == '~' ||
  previous == '(' ||
  previous.to_int() > 0x7f
}

///|
fn matching_prefix(characters : Array[Char], index : Int) -> String? {
  for prefix in autolink_prefixes {
    let prefix_characters = prefix.to_array()
    if index + prefix_characters.length() > characters.length() {
      continue
    }
    let mut matches = true
    for offset = 0; offset < prefix_characters.length(); offset = offset + 1 {
      if characters[index + offset] != prefix_characters[offset] {
        matches = false
        break
      }
    }
    if matches {
      return Some(prefix)
    }
  }
  None
}

///|
/// GFM valid domain: segments of alphanumerics, `-` and `_` separated by
/// periods, at least one period, and no `_` in the last two segments.
fn has_valid_domain(characters : Array[Char], start : Int, end : Int) -> Bool {
  let mut domain_end = start
  while domain_end < end &&
        (
          is_ascii_alphanumeric(characters[domain_end]) ||
          characters[domain_end] == '-' ||
          characters[domain_end] == '_' ||
          characters[domain_end] == '.'
        ) {
    domain_end = domain_end + 1
  }
  let domain = character_slice(characters, start, domain_end)
  let segments = domain
    .split(".")
    .map(fn(segment) { segment.to_owned() })
    .collect()
  if segments.length() < 2 ||
    segments.iter().any(fn(segment) { segment.is_empty() }) {
    return false
  }
  !segments[segments.length() - 1].contains("_") &&
  !segments[segments.length() - 2].contains("_")
}

///|
fn count_character(
  characters : Array[Char],
  start : Int,
  end : Int,
  target : Char,
) -> Int {
  let mut count = 0
  for index = start; index < end; index = index + 1 {
    if characters[index] == target {
      count = count + 1
    }
  }
  count
}

///|
/// Drops trailing punctuation, unbalanced `)` and a trailing entity-like
/// `&name;` from a candidate URL, as GFM's extended autolink path validation does.
fn trimmed_autolink_end(
  characters : Array[Char],
  start : Int,
  end : Int,
) -> Int {
  let mut end = end
  while end > start {
    let last = characters[end - 1]
    if last == '?' ||
      last == '!' ||
      last == '.' ||
      last == ',' ||
      last == ':' ||
      last == '*' ||
      last == '_' ||
      last == '~' {
      end = end - 1
    } else if last == ')' &&
      count_character(characters, start, end, ')') >
      count_character(characters, start, end, '(') {
      end = end - 1
    } else if last == ';' {
      let mut entity_start = end - 1
      while entity_start > start &&
            is_ascii_alphanumeric(characters[entity_start - 1]) {
        entity_start = entity_start - 1
      }
      if entity_start > start &&
        entity_start < end - 1 &&
        characters[entity_start - 1] == '&' {
        end = entity_start - 1
      } else {
        break
      }
    } else {
      break
    }
  }
  end
}

///|
/// Escapes `text` for HTML and links bare URLs in it.
fn render_text_with_autolinks(text : String) -> String {
  let characters = text.to_array()
  let output = StringBuilder()
  let mut plain_start = 0
  let mut index = 0
  while index < characters.length() {
    let prefix = if can_start_autolink(characters, index) {
      matching_prefix(characters, index)
    } else {
      None
    }
    match prefix {
      None => index = index + 1
      Some(prefix) => {
        let domain_start = if prefix == "www." {
          index
        } else {
          index + prefix.length()
        }
        let mut end = index
        while end < characters.length() &&
              !is_autolink_whitespace(characters[end]) &&
              characters[end] != '<' &&
              characters[end].to_int() <= 0x7f {
          end = end + 1
        }
        end = trimmed_autolink_end(characters, index, end)
        if end <= domain_start ||
          !has_valid_domain(characters, domain_start, end) {
          index = index + 1
          continue
        }
        output.write_string(
          escape_html(character_slice(characters, plain_start, index)),
        )
        let url = character_slice(characters, index, end)
        let href = if prefix == "www." { "http://\{url}" } else { url }
        output.write_string(
          "<a href=\"\{escape_attribute(href)}\">\{escape_html(url)}</a>",
        )
        index = end
        plain_start = end
      }
    }
  }
  output.write_string(
    escape_html(character_slice(characters, plain_start, characters.length())),
  )
  output.to_string()
}
