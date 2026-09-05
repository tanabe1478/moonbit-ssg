///|
fn test_parent_directory(path : String) -> String {
  let characters = path.to_array()
  let mut separator = -1
  for index = 0; index < characters.length(); index = index + 1 {
    if characters[index] == '/' {
      separator = index
    }
  }
  if separator < 0 {
    ""
  } else if separator == 0 {
    "/"
  } else {
    path[:separator].to_owned()
  }
}

///|
pub fn test_join_path(parent : String, child : String) -> String {
  if parent.has_suffix("/") {
    "\{parent}\{child}"
  } else {
    "\{parent}/\{child}"
  }
}

///|
pub fn test_ensure_directory(path : String) -> Unit raise @fs.IOError {
  if path.is_empty() || @fs.path_exists(path) {
    return
  }
  let parent = test_parent_directory(path)
  if !parent.is_empty() && parent != path {
    test_ensure_directory(parent)
  }
  @fs.create_dir(path)
}

///|
pub fn test_remove_tree(path : String) -> Unit raise @fs.IOError {
  if !@fs.path_exists(path) {
    return
  }
  if @fs.is_dir(path) {
    for name in @fs.read_dir(path) {
      test_remove_tree(test_join_path(path, name))
    }
    @fs.remove_dir(path)
  } else {
    @fs.remove_file(path)
  }
}
