///|
fn deployment_context(root : String) -> @ssg.PublishingContext {
  {
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
}

///|
test "build GitHub deployment remotes" {
  inspect(
    @ssg.github_deployment_remote("owner/site"),
    content="git@github.com:owner/site.git",
  )
  inspect(
    @ssg.github_deployment_remote("owner/site", use_ssh=false),
    content="https://github.com/owner/site.git",
  )
}

///|
test "execute the built-in Git deployment only in deploy mode" {
  let root = "/tmp/moonbit-ssg-deploy-\{@env.now()}"
  let output = test_join_path(root, "Output")
  let deployment = test_join_path(root, "Deployment/Git")
  test_ensure_directory(output)
  @fs.write_string_to_file(test_join_path(output, "index.html"), "site")
  let commands : Array[String] = []
  let runner = fn(command : @ssg.DeploymentCommand) {
    let rendered = command.executable + " " + command.arguments.join(" ")
    commands.push(rendered)
    if rendered == "git checkout pages" {
      Err("branch missing")
    } else {
      Ok(())
    }
  }
  let step = @ssg.git_deployment_step(
    {
      remote: "git@example.com:site.git",
      branch: "pages",
      working_directory: deployment,
      commit_message: "Deploy fixture",
    },
    runner,
  )
  @ssg.execute_publish_pipeline(deployment_context(root), [step]).unwrap()
  |> ignore
  inspect(commands.length(), content="0")
  @ssg.execute_publish_pipeline(deployment_context(root), [step], deploy=true).unwrap()
  |> ignore
  debug_inspect(
    commands,
    content=(
      #|[
      #|  "git init",
      #|  "git remote add origin git@example.com:site.git",
      #|  "git remote set-url origin git@example.com:site.git",
      #|  "git pull origin pages",
      #|  "git checkout pages",
      #|  "git checkout -b pages",
      #|  "git add .",
      #|  "git commit -a -m Deploy fixture --allow-empty",
      #|  "git push origin pages",
      #|]
    ),
  )
  inspect(
    @fs.read_file_to_string(test_join_path(deployment, "index.html")),
    content="site",
  )
  test_remove_tree(root)
}

///|
test "synchronize deployment output while preserving Git metadata" {
  let root = "/tmp/moonbit-ssg-deploy-sync-\{@env.now()}"
  let output = test_join_path(root, "Output")
  let working = test_join_path(root, "Deployment/Git")
  test_ensure_directory(output)
  test_ensure_directory(test_join_path(working, ".git"))
  @fs.write_string_to_file(test_join_path(output, "index.html"), "new site")
  @fs.write_string_to_file(test_join_path(working, "obsolete.html"), "old")
  @fs.write_string_to_file(test_join_path(working, ".git/config"), "metadata")
  let configuration = @ssg.default_git_deployment_configuration(
    "git@example.com:site.git", working,
  )
  @ssg.sync_git_deployment_output(output, configuration).unwrap()
  inspect(
    @fs.path_exists(test_join_path(working, "obsolete.html")),
    content="false",
  )
  inspect(
    @fs.read_file_to_string(test_join_path(working, "index.html")),
    content="new site",
  )
  inspect(
    @fs.read_file_to_string(test_join_path(working, ".git/config")),
    content="metadata",
  )
  test_remove_tree(root)
}

///|
test "report required Git command failures with command context" {
  let root = "/tmp/moonbit-ssg-deploy-error-\{@env.now()}"
  test_ensure_directory(test_join_path(root, "Output"))
  let step = @ssg.github_deployment_step(
    "owner/site",
    test_join_path(root, "Deployment"),
    fn(command) {
      if command.arguments.length() > 1 &&
        command.arguments[0] == "remote" &&
        command.arguments[1] == "set-url" {
        Err("permission denied")
      } else {
        Ok(())
      }
    },
  )
  let result = @ssg.execute_publish_pipeline(
    deployment_context(root),
    [step],
    deploy=true,
  )
  debug_inspect(
    result,
    content="Err(\"Git (git@github.com:owner/site.git): git remote set-url origin git@github.com:owner/site.git failed: permission denied\")",
  )
  test_remove_tree(root)
}
