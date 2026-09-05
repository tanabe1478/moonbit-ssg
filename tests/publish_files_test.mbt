///|
test "copy Publish files folders and theme resources" {
  let root = "/tmp/moonbit-ssg-copy-\{@env.now()}"
  let resources = test_join_path(root, "Resources")
  let output = test_join_path(root, "Output")
  test_ensure_directory(test_join_path(resources, "nested"))
  test_ensure_directory(test_join_path(root, "Theme"))
  @fs.write_string_to_file(test_join_path(resources, "one.txt"), "one")
  @fs.write_string_to_file(test_join_path(resources, "nested/two.txt"), "two")
  @fs.write_string_to_file(test_join_path(root, "Theme/styles.css"), "body{}")
  @ssg.copy_publish_file(
    test_join_path(resources, "one.txt"),
    output,
    target_folder="assets",
  )
  @ssg.copy_publish_files(resources, output, target_folder="public")
  @ssg.copy_publish_files(
    resources,
    output,
    target_folder="included",
    include_folder=true,
  )
  @ssg.copy_publish_theme_resources(root, ["Theme/styles.css"], output)
  inspect(
    @fs.read_file_to_string(test_join_path(output, "assets/one.txt")),
    content="one",
  )
  inspect(
    @fs.read_file_to_string(test_join_path(output, "public/nested/two.txt")),
    content="two",
  )
  inspect(
    @fs.read_file_to_string(
      test_join_path(output, "included/Resources/one.txt"),
    ),
    content="one",
  )
  inspect(
    @fs.read_file_to_string(test_join_path(output, "styles.css")),
    content="body{}",
  )
  test_remove_tree(root)
}

///|
test "run file copy operations as publishing steps" {
  let root = "/tmp/moonbit-ssg-copy-step-\{@env.now()}"
  test_ensure_directory(test_join_path(root, "Static/images"))
  @fs.write_string_to_file(test_join_path(root, "favicon.ico"), "icon")
  @fs.write_string_to_file(
    test_join_path(root, "Static/images/logo.txt"),
    "logo",
  )
  let context : @ssg.PublishingContext = {
    site: {
      url: "https://example.com",
      name: "Example",
      description: "",
      language: "en",
      image_path: None,
      favicon_path: None,
    },
    content: @ssg.build_published_content("# Home", [], []),
    root_directory: root,
    output_directory: test_join_path(root, "Output"),
  }
  @ssg.execute_publish_pipeline(context, [
    @ssg.copy_publish_file_step("favicon.ico"),
    @ssg.copy_publish_files_step(
      "Static",
      target_folder="assets",
      include_folder=true,
    ),
  ]).unwrap()
  |> ignore
  inspect(
    @fs.read_file_to_string(test_join_path(root, "Output/favicon.ico")),
    content="icon",
  )
  inspect(
    @fs.read_file_to_string(
      test_join_path(root, "Output/assets/Static/images/logo.txt"),
    ),
    content="logo",
  )
  test_remove_tree(root)
}
