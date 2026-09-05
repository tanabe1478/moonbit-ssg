///|
/// A reusable condition equivalent to Publish's Predicate.
pub(all) struct PublishPredicate[T] {
  matches : (T) -> Bool
}

///|
pub(all) enum SortOrder {
  Ascending
  Descending
} derive(Eq, Debug)

///|
pub fn[T] publish_predicate(matcher : (T) -> Bool) -> PublishPredicate[T] {
  { matches: matcher, }
}

///|
pub fn[T] publish_predicate_any() -> PublishPredicate[T] {
  { matches: fn(_value) { true }, }
}

///|
pub fn[T] PublishPredicate::inverse(
  self : PublishPredicate[T],
) -> PublishPredicate[T] {
  { matches: fn(value) { !(self.matches)(value) }, }
}

///|
pub fn[T] PublishPredicate::and_also(
  self : PublishPredicate[T],
  other : PublishPredicate[T],
) -> PublishPredicate[T] {
  { matches: fn(value) { (self.matches)(value) && (other.matches)(value) }, }
}

///|
pub fn[T] PublishPredicate::or_else(
  self : PublishPredicate[T],
  other : PublishPredicate[T],
) -> PublishPredicate[T] {
  { matches: fn(value) { (self.matches)(value) || (other.matches)(value) }, }
}

///|
fn section_is_selected(section : PublishSection, section_id : String?) -> Bool {
  match section_id {
    Some(id) => section.id == id
    None => true
  }
}

///|
fn content_with_sections(
  content : PublishedContent,
  sections : Array[PublishSection],
) -> PublishedContent {
  { index: content.index, sections, pages: content.pages, }
}

///|
fn content_with_pages(
  content : PublishedContent,
  pages : Array[PublishPage],
) -> PublishedContent {
  { index: content.index, sections: content.sections, pages, }
}

///|
/// Adds one programmatically-created item to its section.
pub fn add_publish_item(
  content : PublishedContent,
  item : PublishItem,
) -> Result[PublishedContent, String] {
  let sections : Array[PublishSection] = []
  let mut found = false
  for section in content.sections {
    if section.id == item.section_id {
      found = true
      let items = section.items.map(fn(item) { item })
      items.push(item)
      sections.push({ id: section.id, content: section.content, items, })
    } else {
      sections.push(section)
    }
  }
  if found {
    Ok(content_with_sections(content, sections))
  } else {
    Err("unknown section: \{item.section_id}")
  }
}

///|
/// Adds or replaces a free-form page at the same path.
pub fn add_publish_page(
  content : PublishedContent,
  page : PublishPage,
) -> PublishedContent {
  let pages = content.pages.filter(fn(current) { current.path != page.path })
  pages.push(page)
  content_with_pages(content, pages)
}

///|
/// Removes matching items from one section, or every section when omitted.
pub fn remove_publish_items(
  content : PublishedContent,
  predicate : PublishPredicate[PublishItem],
  section_id? : String,
) -> PublishedContent {
  let sections = content.sections.map(fn(section) {
    if section_is_selected(section, section_id) {
      {
        id: section.id,
        content: section.content,
        items: section.items.filter(fn(item) { !(predicate.matches)(item) }),
      }
    } else {
      section
    }
  })
  content_with_sections(content, sections)
}

///|
/// Applies a fallible mutation to matching items. Errors include the item path.
pub fn mutate_publish_items(
  content : PublishedContent,
  predicate : PublishPredicate[PublishItem],
  mutation : (PublishItem) -> Result[PublishItem, String],
  section_id? : String,
) -> Result[PublishedContent, String] {
  let sections : Array[PublishSection] = []
  for section in content.sections {
    if !section_is_selected(section, section_id) {
      sections.push(section)
      continue
    }
    let items : Array[PublishItem] = []
    for item in section.items {
      if !(predicate.matches)(item) {
        items.push(item)
        continue
      }
      match mutation(item) {
        Ok(updated) => items.push(updated)
        Err(error) =>
          return Err("\{item.path()}: item mutation failed: \{error}")
      }
    }
    sections.push({ id: section.id, content: section.content, items, })
  }
  Ok(content_with_sections(content, sections))
}

///|
/// Mutates one item identified by section and relative path.
pub fn mutate_publish_item(
  content : PublishedContent,
  section_id : String,
  relative_path : String,
  mutation : (PublishItem) -> Result[PublishItem, String],
) -> Result[PublishedContent, String] {
  let predicate = publish_predicate(fn(item : PublishItem) {
    item.relative_path == relative_path
  })
  let mut found = false
  for section in content.sections {
    if section.id == section_id {
      for item in section.items {
        if (predicate.matches)(item) {
          found = true
        }
      }
    }
  }
  if !found {
    return Err("item not found: /\{section_id}/\{relative_path}")
  }
  mutate_publish_items(content, predicate, mutation, section_id~)
}

///|
/// Mutates every matching page and wraps errors with the page path.
pub fn mutate_publish_pages(
  content : PublishedContent,
  predicate : PublishPredicate[PublishPage],
  mutation : (PublishPage) -> Result[PublishPage, String],
) -> Result[PublishedContent, String] {
  let pages : Array[PublishPage] = []
  for page in content.pages {
    if !(predicate.matches)(page) {
      pages.push(page)
      continue
    }
    match mutation(page) {
      Ok(updated) => pages.push(updated)
      Err(error) => return Err("/\{page.path}: page mutation failed: \{error}")
    }
  }
  Ok(content_with_pages(content, pages))
}

///|
/// Sorts items in one section, or all sections when omitted.
pub fn sort_publish_items(
  content : PublishedContent,
  compare : (PublishItem, PublishItem) -> Int,
  order? : SortOrder = Ascending,
  section_id? : String,
) -> PublishedContent {
  let sections = content.sections.map(fn(section) {
    if !section_is_selected(section, section_id) {
      return section
    }
    let items = section.items.map(fn(item) { item })
    items.sort_by(fn(left, right) {
      let result = compare(left, right)
      match order {
        Ascending => result
        Descending => -result
      }
    })
    { id: section.id, content: section.content, items, }
  })
  content_with_sections(content, sections)
}
