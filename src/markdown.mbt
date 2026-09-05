///|
fn escape_html(value : String) -> String {
  value
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
}

///|
fn escape_attribute(value : String) -> String {
  escape_html(value).replace_all(old="\"", new="&quot;")
}

///|
fn find_definition(
  definitions : Array[@markdown.LinkDefinition],
  label : String,
) -> @markdown.LinkDefinition? {
  let normalized = label.trim().to_lower().to_owned()
  for definition in definitions {
    if definition.label.trim().to_lower() == normalized {
      return Some(definition)
    }
  }
  None
}

///|
fn render_link(
  children : Array[@markdown.Inline],
  url : String,
  title : String,
  definitions : Array[@markdown.LinkDefinition],
) -> String {
  let title_attribute = if title.is_empty() {
    ""
  } else {
    " title=\"\{escape_attribute(title)}\""
  }
  "<a href=\"\{escape_attribute(url)}\"\{title_attribute}>\{render_inlines(children, definitions)}</a>"
}

///|
fn render_image(alt : String, url : String, title : String) -> String {
  let alt_attribute = if alt.is_empty() {
    ""
  } else {
    " alt=\"\{escape_attribute(alt)}\""
  }
  let title_attribute = if title.is_empty() {
    ""
  } else {
    " title=\"\{escape_attribute(title)}\""
  }
  "<img src=\"\{escape_attribute(url)}\"\{alt_attribute}\{title_attribute}/>"
}

///|
fn render_inline(
  inline : @markdown.Inline,
  definitions : Array[@markdown.LinkDefinition],
) -> String {
  match inline {
    @markdown.Inline::Text(content~, ..) => escape_html(content)
    @markdown.Inline::SoftBreak(..) => " "
    @markdown.Inline::HardBreak(..) => "<br>"
    @markdown.Inline::Emphasis(children~, ..) =>
      "<em>\{render_inlines(children, definitions)}</em>"
    @markdown.Inline::Strong(children~, ..) =>
      "<strong>\{render_inlines(children, definitions)}</strong>"
    @markdown.Inline::Strikethrough(children~, ..) =>
      "<s>\{render_inlines(children, definitions)}</s>"
    @markdown.Inline::Code(content~, ..) =>
      "<code>\{escape_html(content)}</code>"
    @markdown.Inline::Link(children~, url~, title~, ..) =>
      render_link(children, url, title, definitions)
    @markdown.Inline::RefLink(children~, label~, ..) =>
      match find_definition(definitions, label) {
        Some(definition) =>
          render_link(children, definition.url, definition.title, definitions)
        None =>
          "[\{render_inlines(children, definitions)}][\{escape_html(label)}]"
      }
    @markdown.Inline::Autolink(url~, is_email~, ..) => {
      let href = if is_email { "mailto:\{url}" } else { url }
      "<a href=\"\{escape_attribute(href)}\">\{escape_html(url)}</a>"
    }
    @markdown.Inline::Image(alt~, url~, title~, ..) =>
      render_image(alt, url, title)
    @markdown.Inline::RefImage(alt~, label~, ..) =>
      match find_definition(definitions, label) {
        Some(definition) => render_image(alt, definition.url, definition.title)
        None => "![\{escape_html(alt)}][\{escape_html(label)}]"
      }
    @markdown.Inline::HtmlInline(html~, ..) => html
    @markdown.Inline::WikiLink(target~, label~, fragment~, ..) => {
      let suffix = if fragment.is_empty() { "" } else { "#\{fragment}" }
      let href = "\{target}\{suffix}"
      let text = if label.is_empty() { href } else { label }
      "<a href=\"\{escape_attribute(href)}\">\{escape_html(text)}</a>"
    }
    @markdown.Inline::Directive(label~, ..) => escape_html(label)
    @markdown.Inline::FootnoteReference(label~, ..) =>
      "[^\{escape_html(label)}]"
  }
}

///|
fn render_inlines(
  inlines : Array[@markdown.Inline],
  definitions : Array[@markdown.LinkDefinition],
) -> String {
  let rendered : Array[String] = []
  for inline in inlines {
    rendered.push(render_inline(inline, definitions))
  }
  rendered.join("")
}

///|
fn is_standalone_image(inlines : Array[@markdown.Inline]) -> Bool {
  if inlines.length() != 1 {
    return false
  }
  match inlines[0] {
    @markdown.Inline::Image(..) | @markdown.Inline::RefImage(..) => true
    _ => false
  }
}

///|
fn code_with_trailing_newline(code : String) -> String {
  let escaped = escape_html(code)
  if escaped.is_empty() || escaped.has_suffix("\n") {
    escaped
  } else {
    "\{escaped}\n"
  }
}

///|
fn character_slice(characters : Array[Char], start : Int, end : Int) -> String {
  let output = StringBuilder()
  for index = start; index < end; index = index + 1 {
    output.write_char(characters[index])
  }
  output.to_string()
}

///|
fn highlight_shell(code : String) -> String {
  let characters = code.to_array()
  let output = StringBuilder()
  let mut index = 0
  while index < characters.length() {
    if characters[index] == '\'' {
      let start = index
      index = index + 1
      while index < characters.length() && characters[index] != '\'' {
        index = index + 1
      }
      if index < characters.length() {
        index = index + 1
      }
      output.write_string(
        "<span class=\"hljs-string\">\{escape_html(character_slice(characters, start, index))}</span>",
      )
    } else {
      output.write_string(
        escape_html(character_slice(characters, index, index + 1)),
      )
      index = index + 1
    }
  }
  output.to_string()
}

///|
fn is_identifier_start(character : Char) -> Bool {
  (character >= 'a' && character <= 'z') ||
  (character >= 'A' && character <= 'Z') ||
  character == '_'
}

///|
fn is_identifier_continue(character : Char) -> Bool {
  is_identifier_start(character) || (character >= '0' && character <= '9')
}

///|
fn swift_token_class(token : String) -> String? {
  if token == "try" || token == "optional" {
    Some("hljs-keyword")
  } else if token == "true" || token == "false" || token == "nil" {
    Some("hljs-literal")
  } else if !token.is_empty() &&
    token.to_array()[0] >= 'A' &&
    token.to_array()[0] <= 'Z' {
    Some("hljs-type")
  } else {
    None
  }
}

///|
fn highlight_swift(code : String) -> String {
  let characters = code.to_array()
  let output = StringBuilder()
  let mut index = 0
  while index < characters.length() {
    if characters[index] == '/' &&
      index + 1 < characters.length() &&
      characters[index + 1] == '/' {
      let start = index
      while index < characters.length() && characters[index] != '\n' {
        index = index + 1
      }
      output.write_string(
        "<span class=\"hljs-comment\">\{escape_html(character_slice(characters, start, index))}</span>",
      )
    } else if characters[index] == '\"' {
      let start = index
      index = index + 1
      while index < characters.length() {
        if characters[index] == '\"' && characters[index - 1] != '\\' {
          index = index + 1
          break
        }
        index = index + 1
      }
      output.write_string(
        "<span class=\"hljs-string\">\{escape_html(character_slice(characters, start, index))}</span>",
      )
    } else if is_identifier_start(characters[index]) {
      let start = index
      index = index + 1
      while index < characters.length() &&
            is_identifier_continue(characters[index]) {
        index = index + 1
      }
      let token = character_slice(characters, start, index)
      match swift_token_class(token) {
        Some(class_name) =>
          output.write_string(
            "<span class=\"\{class_name}\">\{escape_html(token)}</span>",
          )
        None => output.write_string(escape_html(token))
      }
    } else {
      output.write_string(
        escape_html(character_slice(characters, index, index + 1)),
      )
      index = index + 1
    }
  }
  output.to_string()
}

///|
fn highlight_code(code : String, language : String) -> String {
  if language == "sh" || language == "bash" {
    highlight_shell(code)
  } else if language == "swift" {
    highlight_swift(code)
  } else {
    escape_html(code)
  }
}

///|
fn first_word(value : String) -> String {
  match value.trim().split(" ").find_first(fn(part) { !part.is_empty() }) {
    Some(word) => word.to_owned()
    None => ""
  }
}

///|
fn youtube_embed(blocks : Array[@markdown.Block]) -> String? {
  if blocks.length() != 1 {
    return None
  }
  let text = match blocks[0] {
    @markdown.Block::Paragraph(children~, ..) if children.length() == 1 =>
      match children[0] {
        @markdown.Inline::Text(content~, ..) => content
        _ => return None
      }
    _ => return None
  }
  let prefix = "youtube "
  if !text.has_prefix(prefix) {
    return None
  }
  let url = text[prefix.length():].trim().to_owned()
  let id = if url.has_prefix("https://youtu.be") {
    url["https://youtu.be".length():].split("?").to_array()[0].to_owned()
  } else {
    match url.find("v=") {
      Some(start) => url[start + 2:].split("&").to_array()[0].to_owned()
      None => return None
    }
  }
  Some(
    "<div class=\"youtube\"><iframe width=\"560\" height=\"315\" src=\"https://www.youtube.com/embed/\{escape_attribute(id)}\" frameborder=\"0\" allow=\"accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture\" allowfullscreen></iframe></div>",
  )
}

///|
fn render_list_item(
  item : @markdown.ListItem,
  _tight : Bool,
  definitions : Array[@markdown.LinkDefinition],
) -> String {
  let content : Array[String] = []
  for child in item.children {
    match child {
      @markdown.Block::Paragraph(children~, ..) =>
        content.push(
          render_inlines(children, definitions).trim_end().to_owned(),
        )
      _ => content.push(render_block(child, definitions))
    }
  }
  "<li>\{content.join("")}</li>"
}

///|
fn render_bullet_list(
  items : Array[@markdown.ListItem],
  tight : Bool,
  definitions : Array[@markdown.LinkDefinition],
) -> String {
  // Ink's nested-list reader keeps consuming sibling markers once it enters
  // an indented list. Recreate that shape from the CommonMark tree.
  if items.length() > 1 && items[0].children.length() == 2 {
    match items[0].children[1] {
      @markdown.Block::BulletList(items=nested_items, ..) => {
        let inner : Array[String] = []
        for item in nested_items {
          inner.push(render_list_item(item, true, definitions))
        }
        for index = 1; index < items.length(); index = index + 1 {
          for child in items[index].children {
            match child {
              @markdown.Block::Paragraph(children~, ..) =>
                inner.push(
                  "<li>\{render_inlines(children, definitions).trim_end()}</li>",
                )
              @markdown.Block::BulletList(items=children, ..) =>
                for item in children {
                  inner.push(render_list_item(item, true, definitions))
                }
              _ => ()
            }
          }
        }
        let outer_text = match items[0].children[0] {
          @markdown.Block::Paragraph(children~, ..) =>
            render_inlines(children, definitions).trim_end().to_owned()
          _ => ""
        }
        return "<ul><li>\{outer_text}<ul>\{inner.join("")}</ul></li></ul>"
      }
      _ => ()
    }
  }
  let rendered : Array[String] = []
  for item in items {
    rendered.push(render_list_item(item, tight, definitions))
  }
  "<ul>\{rendered.join("")}</ul>"
}

///|
fn render_ordered_list(
  start : Int,
  items : Array[@markdown.ListItem],
  tight : Bool,
  definitions : Array[@markdown.LinkDefinition],
) -> String {
  let rendered : Array[String] = []
  if !tight && items.length() > 1 {
    for index = 0; index < items.length(); index = index + 1 {
      let number = start + index
      let start_attribute = if number == 1 {
        ""
      } else {
        " start=\"\{number}\""
      }
      rendered.push(
        "<ol\{start_attribute}>\{render_list_item(items[index], true, definitions)}</ol>",
      )
    }
    return rendered.join("")
  }
  for item in items {
    rendered.push(render_list_item(item, tight, definitions))
  }
  let start_attribute = if start == 1 { "" } else { " start=\"\{start}\"" }
  "<ol\{start_attribute}>\{rendered.join("")}</ol>"
}

///|
fn table_alignment(align : @markdown.TableAlign) -> String {
  match align {
    @markdown.TableAlign::Left => " align=\"left\""
    @markdown.TableAlign::Center => " align=\"center\""
    @markdown.TableAlign::Right => " align=\"right\""
    @markdown.TableAlign::None => ""
  }
}

///|
fn render_table_cell(
  cell : @markdown.TableCell,
  tag : String,
  align : @markdown.TableAlign,
  definitions : Array[@markdown.LinkDefinition],
) -> String {
  "<\{tag}\{table_alignment(align)}>\{render_inlines(cell.children, definitions)}</\{tag}>"
}

///|
fn alignment_at(
  alignments : Array[@markdown.TableAlign],
  index : Int,
) -> @markdown.TableAlign {
  match alignments.get(index) {
    Some(align) => align
    None => @markdown.TableAlign::None
  }
}

///|
fn render_block(
  block : @markdown.Block,
  definitions : Array[@markdown.LinkDefinition],
) -> String {
  match block {
    @markdown.Block::ThematicBreak(..) => "<hr>"
    @markdown.Block::Heading(level~, children~, ..) => {
      let content = render_inlines(children, definitions)
        .trim_end()
        .replace_all(old="　", new="")
      "<h\{level}>\{content}</h\{level}>"
    }
    @markdown.Block::Paragraph(children~, ..) => {
      let content = render_inlines(children, definitions).trim_end().to_owned()
      if is_standalone_image(children) {
        content
      } else {
        "<p>\{content}</p>"
      }
    }
    @markdown.Block::FencedCode(info~, code~, ..) => {
      let language = first_word(info)
      let code = code.trim(chars="\n").to_owned()
      if language.is_empty() || language == "no-highlight" {
        "<pre><code>\{code_with_trailing_newline(code)}</code></pre>"
      } else {
        "<pre data-language=\"\{escape_attribute(language)}\" class=\"hljs\"><code>\{highlight_code(code, language)}\n</code></pre>"
      }
    }
    @markdown.Block::IndentedCode(code~, ..) =>
      "<pre><code>\{code_with_trailing_newline(code)}</code></pre>"
    @markdown.Block::Blockquote(children~, ..) =>
      match youtube_embed(children) {
        Some(embed) => embed
        None =>
          "<blockquote>\{render_blocks(children, definitions)}</blockquote>"
      }
    @markdown.Block::BulletList(items~, tight~, ..) =>
      render_bullet_list(items, tight, definitions)
    @markdown.Block::OrderedList(start~, items~, tight~, ..) =>
      render_ordered_list(start, items, tight, definitions)
    @markdown.Block::HtmlBlock(html~, ..) => html
    @markdown.Block::Table(header~, alignments~, rows~, ..) => {
      let headings : Array[String] = []
      for index = 0; index < header.length(); index = index + 1 {
        headings.push(
          render_table_cell(
            header[index],
            "th",
            alignment_at(alignments, index),
            definitions,
          ),
        )
      }
      let body_rows : Array[String] = []
      for row in rows {
        let cells : Array[String] = []
        for index = 0; index < row.length(); index = index + 1 {
          cells.push(
            render_table_cell(
              row[index],
              "td",
              alignment_at(alignments, index),
              definitions,
            ),
          )
        }
        body_rows.push("<tr>\{cells.join("")}</tr>")
      }
      let head = if header.is_empty() {
        ""
      } else {
        "<thead><tr>\{headings.join("")}</tr></thead>"
      }
      let body = if body_rows.is_empty() {
        ""
      } else {
        "<tbody>\{body_rows.join("")}</tbody>"
      }
      "<table>\{head}\{body}</table>"
    }
    @markdown.Block::BlankLines(..) => ""
    @markdown.Block::Attributed(block~, ..) => render_block(block, definitions)
    @markdown.Block::MathBlock(value~, ..) =>
      "<pre><code>\{code_with_trailing_newline(value)}</code></pre>"
    @markdown.Block::Directive(children~, ..) =>
      render_blocks(children, definitions)
    @markdown.Block::DefinitionList(items~, ..) => {
      let rendered : Array[String] = []
      for item in items {
        rendered.push("<dt>\{render_inlines(item.term, definitions)}</dt>")
        for definition in item.definitions {
          rendered.push("<dd>\{render_inlines(definition, definitions)}</dd>")
        }
      }
      "<dl>\{rendered.join("")}</dl>"
    }
    @markdown.Block::Alert(children~, ..) =>
      "<blockquote>\{render_blocks(children, definitions)}</blockquote>"
    @markdown.Block::FootnoteDefinition(..) => ""
  }
}

///|
fn render_blocks(
  blocks : Array[@markdown.Block],
  definitions : Array[@markdown.LinkDefinition],
) -> String {
  let rendered : Array[String] = []
  for block in blocks {
    rendered.push(render_block(block, definitions))
  }
  rendered.join("")
}

///|
fn is_ascii_whitespace(character : Char) -> Bool {
  character == ' ' ||
  character == '\t' ||
  character == '\r' ||
  character == '\n'
}

///|
fn normalize_ink_line_endings(source : String) -> String {
  let characters = source.to_array()
  let output = StringBuilder()
  let mut index = 0
  let mut at_structural_line_start = true
  let mut standalone_image_line = false
  while index < characters.length() {
    if characters[index] == '\r' &&
      index + 1 < characters.length() &&
      characters[index + 1] == '\n' {
      index = index + 2
      while index < characters.length() &&
            is_ascii_whitespace(characters[index]) {
        index = index + 1
      }
      if standalone_image_line ||
        (
          index < characters.length() &&
          (
            characters[index] == '#' ||
            characters[index] == '<' ||
            characters[index] == '`'
          )
        ) {
        output.write_string("\n\n")
        at_structural_line_start = true
      } else {
        output.write_char(' ')
        at_structural_line_start = false
      }
      standalone_image_line = false
    } else {
      if at_structural_line_start && characters[index] == '!' {
        standalone_image_line = true
      }
      output.write_char(characters[index])
      at_structural_line_start = characters[index] == '\n'
      index = index + 1
    }
  }
  output.to_string().replace_all(old="\n　\n", new=" ")
}

///|
fn inline_plain_text(inline : @markdown.Inline) -> String {
  match inline {
    @markdown.Inline::Text(content~, ..)
    | @markdown.Inline::Code(content~, ..) => content
    @markdown.Inline::SoftBreak(..) => " "
    @markdown.Inline::HardBreak(..) => "\n"
    @markdown.Inline::Emphasis(children~, ..)
    | @markdown.Inline::Strong(children~, ..)
    | @markdown.Inline::Strikethrough(children~, ..)
    | @markdown.Inline::Link(children~, ..)
    | @markdown.Inline::RefLink(children~, ..) => inlines_plain_text(children)
    @markdown.Inline::Image(alt~, ..) | @markdown.Inline::RefImage(alt~, ..) =>
      alt
    @markdown.Inline::Autolink(url~, ..) => url
    @markdown.Inline::WikiLink(target~, label~, ..) =>
      if label.is_empty() {
        target
      } else {
        label
      }
    @markdown.Inline::Directive(label~, ..) => label
    @markdown.Inline::HtmlInline(..) => ""
    @markdown.Inline::FootnoteReference(label~, ..) => label
  }
}

///|
fn inlines_plain_text(inlines : Array[@markdown.Inline]) -> String {
  let parts : Array[String] = []
  for inline in inlines {
    parts.push(inline_plain_text(inline))
  }
  parts.join("")
}

///|
fn markdown_title(source : String) -> String? {
  let document = @markdown.parse(normalize_ink_line_endings(source)).document
  for block in document.children {
    match block {
      @markdown.Block::Heading(level=1, children~, ..) =>
        return Some(inlines_plain_text(children).trim().to_owned())
      _ => ()
    }
  }
  None
}

///|
/// Renders Markdown using Ink-compatible HTML serialization.
pub fn render_markdown(source : String) -> String {
  // Ink compares line terminators with a literal LF in a few readers. Keep
  // that historical behavior while delegating the syntax tree to CommonMark.
  let compatible_source = normalize_ink_line_endings(source)
  let document = @markdown.parse(compatible_source).document
  render_blocks(document.children, document.definitions)
}
