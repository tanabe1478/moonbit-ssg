///|
test "render default and custom favicons" {
  inspect(
    @ssg.render_publish_favicon(@ssg.default_favicon()),
    content="<link rel=\"shortcut icon\" href=\"/images/favicon.png\" type=\"image/png\"/>",
  )
  inspect(
    @ssg.render_publish_favicon({
      path: "https://example.com/icon.svg",
      mime_type: "image/svg+xml",
    }),
    content="<link rel=\"shortcut icon\" href=\"https://example.com/icon.svg\" type=\"image/svg+xml\"/>",
  )
}

///|
test "render Publish audio players" {
  let audio : @ssg.Audio = {
    url: "https://audio.mp3",
    format: "mpeg",
    duration: None,
    byte_size: None,
  }
  inspect(
    @ssg.render_publish_audio_player(audio),
    content="<audio controls><source type=\"audio/mpeg\" src=\"https://audio.mp3\"/></audio>",
  )
  inspect(
    @ssg.render_publish_audio_player(audio, show_controls=false),
    content="<audio><source type=\"audio/mpeg\" src=\"https://audio.mp3\"/></audio>",
  )
}

///|
test "render Publish hosted and embedded video players" {
  inspect(
    @ssg.render_publish_video_player(
      @ssg.Hosted(url="https://video.mp4", format="mp4"),
    ),
    content="<video controls><source type=\"video/mp4\" src=\"https://video.mp4\"/></video>",
  )
  inspect(
    @ssg.render_publish_video_player(@ssg.YouTube(id="123")),
    content="<iframe src=\"https://www.youtube-nocookie.com/embed/123\" frameborder=\"0\" allowfullscreen=\"true\" allow=\"accelerometer; encrypted-media; gyroscope; picture-in-picture\"></iframe>",
  )
  inspect(
    @ssg.render_publish_video_player(@ssg.Vimeo(id="123")),
    content="<iframe src=\"https://player.vimeo.com/video/123\" frameborder=\"0\" allowfullscreen=\"true\" allow=\"accelerometer; encrypted-media; gyroscope; picture-in-picture\"></iframe>",
  )
}
