///|
test "build generic Publish sections pages and metadata" {
  let site = @moonbit-ssg.build_published_content(
    "# Home",
    [
      {
        id: "articles",
        index_source: Some("# Articles"),
        items: [
          {
            slug: "original/path",
            source: (
              #|---
              #|title: Custom item
              #|path: overridden/path
              #|date: 2025-02-03 04:05
              #|lastModified: 2025-02-04 05:06
              #|tags: moonbit, ssg
              #|custom: preserved
              #|rss.guid: stable-id
              #|rss.titlePrefix: "[News] "
              #|rss.titleSuffix: "!"
              #|rss.link: https://example.com/custom
              #|audio.url: https://example.com/episode.mp3
              #|audio.duration: 01:02:03
              #|audio.size: 1234
              #|video.youTube: abc123
              #|---
              #|Body
            ),
          },
        ],
      },
      { id: "notes", index_source: None, items: [], },
    ],
    [
      {
        path: "about/team",
        source: (
          #|---
          #|description: Team page
          #|---
          #|# About us
        ),
      },
    ],
  )
  inspect(site.index.title, content="Home")
  inspect(site.sections[0].content.title, content="Articles")
  inspect(site.sections[1].content.title, content="notes")
  inspect(site.pages[0].path, content="about/team")
  inspect(site.pages[0].content.title, content="About us")
  let item = site.sections[0].items[0]
  inspect(item.path(), content="/articles/overridden/path")
  inspect(item.metadata.get("custom").unwrap(), content="preserved")
  inspect(item.content.last_modified, content="2025-02-04 05:06")
  inspect(item.rss.guid.unwrap(), content="stable-id")
  inspect(item.rss.link.unwrap(), content="https://example.com/custom")
  inspect(item.rss_title(), content="\"[News] \"Custom item\"!\"")
  debug_inspect(
    item.content.audio,
    content=(
      #|Some(
      #|  {
      #|    url: "https://example.com/episode.mp3",
      #|    format: "mp3",
      #|    duration: Some({ hours: 1, minutes: 2, seconds: 3 }),
      #|    byte_size: Some(1234),
      #|  },
      #|)
    ),
  )
  debug_inspect(item.content.video, content="Some(YouTube(id=\"abc123\"))")
}

///|
test "query tags across multiple Publish sections" {
  let site = @moonbit-ssg.build_published_content(
    "# Home",
    [
      {
        id: "articles",
        index_source: None,
        items: [
          {
            slug: "older",
            source: "---\ndate: 2024-01-01 00:00\ntags: shared, article\n---\n# Older",
          },
        ],
      },
      {
        id: "episodes",
        index_source: None,
        items: [
          {
            slug: "newer",
            source: "---\ndate: 2025-01-01 00:00\ntags: shared, audio\n---\n# Newer",
          },
        ],
      },
    ],
    [],
  )
  debug_inspect(
    site.all_items().map(fn(item) { item.path() }),
    content="[\"/articles/older\", \"/episodes/newer\"]",
  )
  debug_inspect(site.all_tags(), content="[\"article\", \"audio\", \"shared\"]")
  debug_inspect(
    site.items_tagged_with("shared").map(fn(item) { item.content.title }),
    content="[\"Newer\", \"Older\"]",
  )
}
