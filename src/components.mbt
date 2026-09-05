///|
/// Website favicon metadata. Publish defaults to `images/favicon.png`.
pub(all) struct Favicon {
  path : String
  mime_type : String
} derive(Eq, Debug)

///|
pub fn default_favicon() -> Favicon {
  { path: "images/favicon.png", mime_type: "image/png", }
}

///|
fn publish_absolute_path(path : String) -> String {
  if path.has_prefix("/") ||
    path.has_prefix("http://") ||
    path.has_prefix("https://") {
    path
  } else {
    "/\{path}"
  }
}

///|
pub fn render_publish_favicon(favicon : Favicon) -> String {
  "<link rel=\"shortcut icon\" href=\"\{xml_text(publish_absolute_path(favicon.path))}\" type=\"\{xml_text(favicon.mime_type)}\"/>"
}

///|
/// Renders Publish's Plot-based inline audio player.
pub fn render_publish_audio_player(
  audio : Audio,
  show_controls? : Bool = true,
) -> String {
  let controls = if show_controls { " controls" } else { "" }
  "<audio\{controls}><source type=\"audio/\{xml_text(audio.format)}\" src=\"\{xml_text(audio.url)}\"/></audio>"
}

///|
fn render_iframe_video(url : String) -> String {
  "<iframe src=\"\{xml_text(url)}\" frameborder=\"0\" allowfullscreen=\"true\" allow=\"accelerometer; encrypted-media; gyroscope; picture-in-picture\"></iframe>"
}

///|
/// Renders hosted, YouTube, and Vimeo players like Publish's VideoPlayer.
pub fn render_publish_video_player(
  video : Video,
  show_controls? : Bool = true,
) -> String {
  match video {
    Hosted(url~, format~) => {
      let controls = if show_controls { " controls" } else { "" }
      "<video\{controls}><source type=\"video/\{xml_text(format)}\" src=\"\{xml_text(url)}\"/></video>"
    }
    YouTube(id~) =>
      render_iframe_video("https://www.youtube-nocookie.com/embed/\{id}")
    Vimeo(id~) => render_iframe_video("https://player.vimeo.com/video/\{id}")
  }
}
