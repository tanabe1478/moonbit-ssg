///|
fn publish_basename(path : String) -> String {
  let trimmed = path.trim_end(chars=['/']).to_owned()
  let characters = trimmed.to_array()
  let mut separator = -1
  for index = 0; index < characters.length(); index = index + 1 {
    if characters[index] == '/' {
      separator = index
    }
  }
  if separator < 0 {
    trimmed
  } else {
    trimmed[separator + 1:].to_owned()
  }
}

///|
fn publish_project_path(root_directory : String, path : String) -> String {
  if path.has_prefix("/") {
    path
  } else {
    join_path(root_directory, path)
  }
}

///|
fn publish_copy_target(
  output_directory : String,
  target_folder : String?,
) -> String {
  match target_folder {
    Some(path) => join_path(output_directory, path.trim(chars=['/']).to_owned())
    None => output_directory
  }
}

///|
/// Copies one file into the output root or a target folder.
pub fn copy_publish_file(
  origin_path : String,
  output_directory : String,
  target_folder? : String,
) -> Unit raise @fs.IOError {
  let target = publish_copy_target(output_directory, target_folder)
  copy_tree(origin_path, join_path(target, publish_basename(origin_path)))
}

///|
/// Copies a folder's contents, optionally including the folder itself.
pub fn copy_publish_files(
  origin_directory : String,
  output_directory : String,
  target_folder? : String,
  include_folder? : Bool = false,
) -> Unit raise @fs.IOError {
  let target = publish_copy_target(output_directory, target_folder)
  if include_folder {
    copy_tree(
      origin_directory,
      join_path(target, publish_basename(origin_directory)),
    )
    return
  }
  ensure_directory(target)
  let names = @fs.read_dir(origin_directory)
  for name in names {
    copy_tree(join_path(origin_directory, name), join_path(target, name))
  }
}

///|
/// Copies files declared by a custom theme from the project root.
pub fn copy_publish_theme_resources(
  root_directory : String,
  resource_paths : Array[String],
  output_directory : String,
) -> Unit raise @fs.IOError {
  for path in resource_paths {
    copy_publish_file(
      publish_project_path(root_directory, path),
      output_directory,
    )
  }
}

///|
pub fn copy_publish_file_step(
  origin_path : String,
  target_folder? : String,
) -> PublishingStep {
  publishing_step("Copy file '\{origin_path}'", fn(context) {
    copy_publish_file(
      publish_project_path(context.root_directory, origin_path),
      context.output_directory,
      target_folder?,
    ) catch {
      @fs.IOError(message) => return Err(message)
    }
    Ok(context)
  })
}

///|
pub fn copy_publish_files_step(
  origin_path : String,
  target_folder? : String,
  include_folder? : Bool = false,
) -> PublishingStep {
  publishing_step("Copy '\{origin_path}' files", fn(context) {
    copy_publish_files(
      publish_project_path(context.root_directory, origin_path),
      context.output_directory,
      target_folder?,
      include_folder~,
    ) catch {
      @fs.IOError(message) => return Err(message)
    }
    Ok(context)
  })
}
