///|
/// Raw Markdown and its URL slug before it is converted into a post.
pub(all) struct PostSource {
  slug : String
  source : String
} derive(Eq, Debug)

///|
/// Content fields needed by the Publish-compatible theme and feeds.
pub(all) struct Post {
  slug : String
  title : String
  description : String
  date : String
  tags : Array[String]
  image_path : String?
  body_html : String
} derive(Eq, Debug)

///|
/// The index, section, and post data loaded from a Publish Content directory.
pub(all) struct SiteContent {
  index_title : String
  section_title : String
  posts : Array[Post]
} derive(Eq, Debug)

///|
pub fn Post::path(self : Post) -> String {
  "/posts/\{self.slug}"
}

///|
pub fn Post::date_day(self : Post) -> String {
  match self.date.split(" ").to_array().get(0) {
    Some(day) => day.to_owned()
    None => self.date
  }
}

///|
fn source_title(markdown : String, fallback : String) -> String {
  markdown_title(markdown).unwrap_or(fallback)
}

///|
fn build_post(post_source : PostSource) -> Post {
  let document = parse_source(post_source.source)
  {
    slug: post_source.slug,
    title: document.item.title.unwrap_or_else(fn() {
      source_title(document.markdown, post_source.slug)
    }),
    description: document.item.description,
    date: document.item.date.unwrap_or(""),
    tags: document.item.tags,
    image_path: document.item.image,
    body_html: render_markdown(document.markdown),
  }
}

///|
/// Builds the deterministic content model without performing file I/O.
pub fn build_site_content(
  index_source : String,
  section_source : String,
  post_sources : Array[PostSource],
) -> SiteContent {
  let index = parse_source(index_source)
  let section = parse_source(section_source)
  {
    index_title: source_title(index.markdown, ""),
    section_title: source_title(section.markdown, "posts"),
    posts: post_sources.map(build_post),
  }
}

///|
/// Returns a copy sorted like the home page and tag detail pages.
pub fn SiteContent::posts_by_descending_date(self : SiteContent) -> Array[Post] {
  let posts = self.posts.map(fn(post) { post })
  posts.sort_by(fn(left, right) { right.date.compare(left.date) })
  posts
}

///|
fn compare_unicode_scalars(left : String, right : String) -> Int {
  let left_characters = left.to_array()
  let right_characters = right.to_array()
  let count = if left_characters.length() < right_characters.length() {
    left_characters.length()
  } else {
    right_characters.length()
  }
  for index = 0; index < count; index = index + 1 {
    let order = left_characters[index].compare(right_characters[index])
    if order != 0 {
      return order
    }
  }
  left_characters.length().compare(right_characters.length())
}

///|
/// Returns every tag once, in the same ascending order used by Publish.
pub fn SiteContent::all_tags(self : SiteContent) -> Array[String] {
  let tags : Array[String] = []
  for post in self.posts {
    for tag in post.tags {
      if !tags.contains(tag) {
        tags.push(tag)
      }
    }
  }
  tags.sort_by(compare_unicode_scalars)
  tags
}

///|
/// Returns posts for a tag in descending date order.
pub fn SiteContent::posts_tagged_with(
  self : SiteContent,
  tag : String,
) -> Array[Post] {
  self.posts_by_descending_date().filter(fn(post) { post.tags.contains(tag) })
}

///|
fn markdown_filename(name : String) -> Bool {
  name.has_suffix(".md") && name != "index.md"
}

///|
fn slug_from_filename(name : String) -> String {
  name[:name.length() - ".md".length()].to_owned()
}

///|
fn join_path(parent : String, child : String) -> String {
  if parent.has_suffix("/") {
    "\{parent}\{child}"
  } else {
    "\{parent}/\{child}"
  }
}

///|
/// Loads the subset of Publish's Content layout used by this site.
pub fn load_site_content(
  content_directory : String,
) -> SiteContent raise @fs.IOError {
  let posts_directory = join_path(content_directory, "posts")
  let names = @fs.read_dir(posts_directory)
  names.sort_by(compare_unicode_scalars)
  let post_sources : Array[PostSource] = []
  for name in names {
    if markdown_filename(name) {
      post_sources.push({
        slug: slug_from_filename(name),
        source: @fs.read_file_to_string(join_path(posts_directory, name)),
      })
    }
  }
  build_site_content(
    @fs.read_file_to_string(join_path(content_directory, "index.md")),
    @fs.read_file_to_string(join_path(posts_directory, "index.md")),
    post_sources,
  )
}
