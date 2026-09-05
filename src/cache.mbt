///|
/// Result of reading or producing a persistent publishing-step cache value.
pub(all) struct PublishCacheValue {
  value : String
  reused : Bool
  path : String
} derive(Eq, Debug)

///|
fn normalized_cache_name(value : String) -> String {
  let characters : Array[Char] = []
  for character in value.to_lower() {
    if character.is_whitespace() {
      characters.push('-')
    } else if (character >= 'a' && character <= 'z') ||
      (character >= '0' && character <= '9') {
      characters.push(character)
    }
  }
  if characters.is_empty() {
    "cache"
  } else {
    String::from_array(characters)
  }
}

///|
fn decode_publish_cache(stored : String, key : String) -> String? {
  match stored.split_once("\n") {
    None => None
    Some((length_source, body_view)) => {
      let key_length = @string.parse_int(length_source) catch {
        _ => return None
      }
      let body = body_view.to_owned()
      if key_length < 0 || key_length > body.length() {
        return None
      }
      let stored_key = match body.get_view(end=key_length) {
        Some(value) => value.to_owned()
        None => return None
      }
      if stored_key != key {
        return None
      }
      body.get_view(start=key_length).map(fn(value) { value.to_owned() })
    }
  }
}

///|
/// Returns a cache entry scoped by publishing step and name. The producer is
/// only called when no entry with the same caller-defined key exists.
pub fn cached_publish_value(
  root_directory : String,
  step_name : String,
  name : String,
  key : String,
  produce : () -> String,
) -> PublishCacheValue raise @fs.IOError {
  let directory = join_path(
    join_path(root_directory, ".publish/Caches"),
    normalized_cache_name(step_name),
  )
  ensure_directory(directory)
  let path = join_path(directory, normalized_cache_name(name))
  if @fs.path_exists(path) {
    match decode_publish_cache(@fs.read_file_to_string(path), key) {
      Some(value) => return { value, reused: true, path, }
      None => ()
    }
  }
  let value = produce()
  @fs.write_string_to_file(path, "\{key.length()}\n\{key}\{value}")
  { value, reused: false, path, }
}
