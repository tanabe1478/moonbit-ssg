///|
fn parent_directory(path : String) -> String {
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
    let output = StringBuilder()
    for index = 0; index < separator; index = index + 1 {
      output.write_char(characters[index])
    }
    output.to_string()
  }
}

///|
fn ensure_directory(path : String) -> Unit raise @fs.IOError {
  if path.is_empty() || @fs.path_exists(path) {
    return
  }
  let parent = parent_directory(path)
  if !parent.is_empty() && parent != path {
    ensure_directory(parent)
  }
  @fs.create_dir(path)
}

///|
fn remove_tree(path : String) -> Unit raise @fs.IOError {
  if !@fs.path_exists(path) {
    return
  }
  if @fs.is_dir(path) {
    let names = @fs.read_dir(path)
    for name in names {
      remove_tree(join_path(path, name))
    }
    @fs.remove_dir(path)
  } else {
    @fs.remove_file(path)
  }
}

///|
fn copy_tree(source : String, destination : String) -> Unit raise @fs.IOError {
  if @fs.is_dir(source) {
    ensure_directory(destination)
    let names = @fs.read_dir(source)
    for name in names {
      copy_tree(join_path(source, name), join_path(destination, name))
    }
  } else {
    ensure_directory(parent_directory(destination))
    @fs.write_bytes_to_file(destination, @fs.read_file_to_bytes(source))
  }
}

///|
fn write_output_file(
  output_directory : String,
  relative_path : String,
  content : String,
) -> Unit raise @fs.IOError {
  let destination = join_path(output_directory, relative_path)
  ensure_directory(parent_directory(destination))
  @fs.write_string_to_file(destination, content)
}

///|
fn join_path(parent : String, child : String) -> String {
  if parent.has_suffix("/") {
    "\{parent}\{child}"
  } else {
    "\{parent}/\{child}"
  }
}
