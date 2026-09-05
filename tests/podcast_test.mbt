///|
fn podcast_configuration() -> @ssg.PodcastFeedConfiguration {
  {
    target_path: "podcast.xml",
    ttl: 120,
    maximum_item_count: 10,
    podcast_type: @ssg.Serial,
    image_url: "https://example.com/podcast.png",
    copyright_text: "2026 Example",
    author: { name: "Jane Doe", email_address: "jane@example.com", },
    description: "A long description",
    subtitle: "A short subtitle",
    is_explicit: false,
    category: "Technology",
    subcategory: Some("Software How-To"),
    new_feed_url: Some("https://example.com/new-feed.xml"),
  }
}

///|
fn podcast_content(audio_metadata : String) -> @ssg.PublishedContent {
  @ssg.build_published_content(
    "# Home",
    [
      {
        id: "episodes",
        index_source: Some("# Episodes"),
        items: [
          {
            slug: "episode-1",
            source: "---\ndate: 2026-01-02 03:04\ndescription: Episode description\n" +
            audio_metadata +
            "\npodcast.episode: 7\npodcast.season: 2\npodcast.explicit: true\n---\n# Episode One\n\nListen [here](/listen).",
          },
        ],
      },
    ],
    [],
  )
}

///|
test "render Publish-compatible podcast metadata and enclosure" {
  let content = podcast_content(
    "audio.url: https://cdn.example.com/episode.mp3\naudio.duration: 01:02:03\naudio.size: 4567",
  )
  let date = @ssg.BuildDate::parse("2026-02-03T04:05:06+0000").unwrap()
  let xml = @ssg.render_publish_podcast_feed(
    {
      url: "https://example.com",
      name: "Example Podcast",
      description: "Site description",
      language: "en",
      image_path: None,
      favicon_path: None,
    },
    content,
    "episodes",
    date,
    podcast_configuration(),
  ).unwrap()
  inspect(
    xml.contains(
      "<itunes:new-feed-url>https://example.com/new-feed.xml</itunes:new-feed-url>",
    ),
    content="true",
  )
  inspect(
    xml.contains(
      "<itunes:category text=\"Technology\"><itunes:category text=\"Software How-To\"/></itunes:category>",
    ),
    content="true",
  )
  inspect(xml.contains("<itunes:type>serial</itunes:type>"), content="true")
  inspect(
    xml.contains("<itunes:explicit>yes</itunes:explicit>"),
    content="true",
  )
  inspect(
    xml.contains("<itunes:duration>01:02:03</itunes:duration>"),
    content="true",
  )
  inspect(xml.contains("<itunes:episode>7</itunes:episode>"), content="true")
  inspect(xml.contains("<itunes:season>2</itunes:season>"), content="true")
  inspect(
    xml.contains(
      "<enclosure url=\"https://cdn.example.com/episode.mp3\" length=\"4567\" type=\"audio/mp3\"/>",
    ),
    content="true",
  )
  inspect(
    xml.contains(
      "<media:content url=\"https://cdn.example.com/episode.mp3\" length=\"4567\" type=\"audio/mp3\" isDefault=\"true\" medium=\"audio\"><media:title type=\"plain\">Episode One</media:title></media:content>",
    ),
    content="true",
  )
  inspect(xml.contains("href=\"https://example.com/listen\""), content="true")
}

///|
test "report incomplete podcast audio metadata" {
  let date = @ssg.BuildDate::parse("2026-02-03T04:05:06").unwrap()
  let result = @ssg.render_publish_podcast_feed(
    {
      url: "https://example.com",
      name: "Example",
      description: "",
      language: "en",
      image_path: None,
      favicon_path: None,
    },
    podcast_content("audio.url: https://cdn.example.com/episode.mp3"),
    "episodes",
    date,
    podcast_configuration(),
  )
  debug_inspect(
    result,
    content="Err(\"/episodes/episode-1: missing podcast audio duration\")",
  )
}

///|
test "report unknown podcast sections" {
  let date = @ssg.BuildDate::parse("2026-02-03T04:05:06").unwrap()
  let result = @ssg.render_publish_podcast_feed(
    {
      url: "https://example.com",
      name: "Example",
      description: "",
      language: "en",
      image_path: None,
      favicon_path: None,
    },
    podcast_content(
      "audio.url: https://cdn.example.com/episode.mp3\naudio.duration: 01:00\naudio.size: 1",
    ),
    "missing",
    date,
    podcast_configuration(),
  )
  debug_inspect(result, content="Err(\"unknown podcast section: missing\")")
}
