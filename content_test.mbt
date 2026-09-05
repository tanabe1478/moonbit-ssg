///|
test "build Publish content model" {
  let site = @moonbit-ssg.build_site_content("# Home", "# My posts", [
    {
      slug: "older",
      source: (
        #|---
        #|date: 2024-01-02 03:04
        #|description: Older post
        #|tags: 技術, diary,
        #|---
        #|# Older title
        #|
        #|Body
      ),
    },
    {
      slug: "newer",
      source: (
        #|---
        #|date: 2025-06-07 08:09
        #|description: ""
        #|tags: diary
        #|---
        #|# Newer title
        #|
        #|New body
      ),
    },
  ])
  inspect(site.index_title, content="Home")
  inspect(site.section_title, content="My posts")
  debug_inspect(
    site.posts.map(fn(post) { post.slug }),
    content="[\"older\", \"newer\"]",
  )
  debug_inspect(
    site.posts[0],
    content=(
      #|{
      #|  slug: "older",
      #|  title: "Older title",
      #|  description: "Older post",
      #|  date: "2024-01-02 03:04",
      #|  tags: ["技術", "diary"],
      #|  image_path: None,
      #|  body_html: "<h1>Older title</h1><p>Body</p>",
      #|}
    ),
  )
  debug_inspect(
    site.posts_by_descending_date().map(fn(post) { post.slug }),
    content="[\"newer\", \"older\"]",
  )
  debug_inspect(site.all_tags(), content="[\"diary\", \"技術\"]")
  debug_inspect(
    site.posts_tagged_with("diary").map(fn(post) { post.slug }),
    content="[\"newer\", \"older\"]",
  )
}

///|
test "prefer metadata title and fall back to slug" {
  let site = @moonbit-ssg.build_site_content("# Home", "# Posts", [
    {
      slug: "metadata-title",
      source: (
        #|---
        #|title: Explicit title
        #|date: 2024-01-01 00:00
        #|---
        #|# Heading title
      ),
    },
    {
      slug: "filename-title",
      source: (
        #|---
        #|date: 2024-01-01 00:00
        #|---
        #|## No level-one heading
      ),
    },
  ])
  debug_inspect(
    site.posts.map(fn(post) { post.title }),
    content="[\"Explicit title\", \"filename-title\"]",
  )
  inspect(site.posts[0].path(), content="/posts/metadata-title")
  inspect(site.posts[0].date_day(), content="2024-01-01")
}
