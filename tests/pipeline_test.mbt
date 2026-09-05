///|
fn pipeline_context() -> @ssg.PublishingContext {
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
    root_directory: "/tmp/project",
    output_directory: "/tmp/project/Output",
  }
}

///|
fn add_page_step(name : String, path : String) -> @ssg.PublishingStep {
  @ssg.publishing_step(name, fn(context) {
    let page = @ssg.build_publish_page(path, "# \{path}")
    Ok(context.with_content(@ssg.add_publish_page(context.content, page)))
  })
}

///|
test "execute grouped conditional optional and plugin steps in order" {
  let plugin = @ssg.publish_plugin("Pages", fn(context) {
    let page = @ssg.build_publish_page("plugin", "# Plugin")
    Ok(context.with_content(@ssg.add_publish_page(context.content, page)))
  })
  let failing = @ssg.publishing_step("Failure", fn(_context) { Err("ignored") })
  let result = @ssg.execute_publish_pipeline(pipeline_context(), [
    @ssg.install_publish_plugin(plugin),
    @ssg.group_publishing_steps([
      add_page_step("Add first", "first"),
      @ssg.conditional_publishing_step(
        false,
        add_page_step("Skipped", "skipped"),
      ),
      @ssg.optional_publishing_step(failing),
      add_page_step("Add last", "last"),
    ]),
  ]).unwrap()
  debug_inspect(
    result.content.pages.map(fn(page) { page.path }),
    content="[\"plugin\", \"first\", \"last\"]",
  )
}

///|
test "only execute deployment steps for deploy pipelines including groups" {
  let deploy = @ssg.deployment_step("Deploy", fn(context) {
    let page = @ssg.build_publish_page("deployed", "# Deployed")
    Ok(context.with_content(@ssg.add_publish_page(context.content, page)))
  })
  let steps = [@ssg.group_publishing_steps([deploy])]
  let generated = @ssg.execute_publish_pipeline(pipeline_context(), steps).unwrap()
  inspect(generated.content.pages.length(), content="0")
  let deployed = @ssg.execute_publish_pipeline(
    pipeline_context(),
    steps,
    deploy=true,
  ).unwrap()
  debug_inspect(
    deployed.content.pages.map(fn(page) { page.path }),
    content="[\"deployed\"]",
  )
}

///|
test "stop a pipeline and report the failing step name" {
  let result = @ssg.execute_publish_pipeline(pipeline_context(), [
    add_page_step("Before", "before"),
    @ssg.publishing_step("Validate", fn(_context) { Err("invalid content") }),
    add_page_step("After", "after"),
  ])
  debug_inspect(result, content="Err(\"Validate: invalid content\")")
}
