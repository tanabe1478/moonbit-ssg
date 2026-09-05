///|
test "parse generic Publish project configuration" {
  let configuration = @ssg.parse_publish_project_configuration(
    (
      #|---
      #|url: https://example.com
      #|name: Example
      #|description: Example site
      #|language: ja
      #|sections: posts, episodes
      #|image: images/site.png
      #|favicon: images/icon.png
      #|tagPath: topics
      #|output: Public
      #|deploymentRemote: git@example.com:owner/site.git
      #|deploymentBranch: pages
      #|deploymentDirectory: .deploy/Site
      #|deploymentCommitMessage: Deploy from test
      #|---
    ),
  ).unwrap()
  inspect(configuration.site.name, content="Example")
  debug_inspect(configuration.section_ids, content="[\"posts\", \"episodes\"]")
  inspect(configuration.tag_base_path.unwrap(), content="topics")
  inspect(configuration.output_directory, content="Public")
  let deployment = configuration.deployment.unwrap()
  inspect(deployment.branch, content="pages")
  let git = deployment.git_configuration("/work/site")
  inspect(git.remote, content="git@example.com:owner/site.git")
  inspect(git.working_directory, content="/work/site/.deploy/Site")
  inspect(git.commit_message, content="Deploy from test")
}

///|
test "validate required generic project settings" {
  debug_inspect(
    @ssg.parse_publish_project_configuration(
      "---\nname: Example\nsections: posts\n---",
    ),
    content="Err(\"site.md is missing required metadata: url\")",
  )
  debug_inspect(
    @ssg.parse_publish_project_configuration(
      "---\nurl: https://example.com\nname: Example\n---",
    ),
    content="Err(\"site.md must define at least one section\")",
  )
}

///|
test "scaffold and generate a Foundation website project" {
  let root = "/tmp/moonbit-ssg-project-\{@env.now()}"
  inspect(
    @ssg.create_publish_project(
      root,
      name="Learning MoonBit",
      first_post_date="2026-09-05 12:34",
    ),
    content="true",
  )
  inspect(
    @ssg.create_publish_project(root, name="Do not overwrite"),
    content="false",
  )
  inspect(
    @fs.read_file_to_string(test_join_path(root, ".gitignore")),
    content=".DS_Store\n.publish\nOutput\n",
  )
  let date = @ssg.BuildDate::parse("2026-09-05T12:35:00+0900").unwrap()
  let output = @ssg.build_publish_project(root, build_date=date).unwrap()
  inspect(output, content="\{root}/Output")
  let index = @fs.read_file_to_string(test_join_path(output, "index.html"))
  inspect(index.contains("Learning MoonBit"), content="true")
  inspect(index.contains("My first post"), content="true")
  inspect(
    @fs.path_exists(test_join_path(output, "posts/first-post/index.html")),
    content="true",
  )
  inspect(
    @fs.path_exists(test_join_path(output, "tags/first/index.html")),
    content="true",
  )
  inspect(@fs.path_exists(test_join_path(output, "feed.rss")), content="true")
  let first_feed = @fs.read_file_to_string(test_join_path(output, "feed.rss"))
  let later_date = @ssg.BuildDate::parse("2027-01-01T00:00:00+0900").unwrap()
  ignore(@ssg.build_publish_project(root, build_date=later_date).unwrap())
  let reused_feed = @fs.read_file_to_string(test_join_path(output, "feed.rss"))
  inspect(reused_feed == first_feed, content="true")
  let post_path = test_join_path(root, "Content/posts/first-post.md")
  let post = @fs.read_file_to_string(post_path)
  @fs.write_string_to_file(post_path, post + "\nUpdated after caching.")
  ignore(@ssg.build_publish_project(root, build_date=later_date).unwrap())
  let updated_feed = @fs.read_file_to_string(test_join_path(output, "feed.rss"))
  inspect(updated_feed == first_feed, content="false")
  inspect(updated_feed.contains("Updated after caching."), content="true")
  inspect(
    @fs.path_exists(test_join_path(output, "sitemap.xml")),
    content="true",
  )
  inspect(
    @fs.read_file_to_string(test_join_path(output, "styles.css")).contains(
      "Publish Foundation theme",
    ),
    content="true",
  )
  test_remove_tree(root)
}
