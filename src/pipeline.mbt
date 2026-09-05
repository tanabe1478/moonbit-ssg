///|
pub(all) enum PublishingStepKind {
  SystemStep
  GenerationStep
  DeploymentStep
} derive(Eq, Debug)

///|
/// Immutable state passed between publishing pipeline steps.
pub(all) struct PublishingContext {
  site : PublishSiteConfig
  content : PublishedContent
  root_directory : String
  output_directory : String
} derive(Eq, Debug)

///|
/// A named transformation in a publishing pipeline.
pub(all) struct PublishingStep {
  name : String
  kind : PublishingStepKind
  operation : (PublishingContext, Bool) -> Result[PublishingContext, String]
}

///|
/// A reusable installer represented using the same context transformation.
pub(all) struct PublishPlugin {
  name : String
  installer : (PublishingContext) -> Result[PublishingContext, String]
}

///|
pub fn PublishingContext::with_content(
  self : PublishingContext,
  content : PublishedContent,
) -> PublishingContext {
  {
    site: self.site,
    content,
    root_directory: self.root_directory,
    output_directory: self.output_directory,
  }
}

///|
pub fn publishing_step(
  name : String,
  operation : (PublishingContext) -> Result[PublishingContext, String],
) -> PublishingStep {
  {
    name,
    kind: GenerationStep,
    operation: fn(context, _deploy) { operation(context) },
  }
}

///|
pub fn deployment_step(
  name : String,
  operation : (PublishingContext) -> Result[PublishingContext, String],
) -> PublishingStep {
  {
    name,
    kind: DeploymentStep,
    operation: fn(context, _deploy) { operation(context) },
  }
}

///|
pub fn empty_publishing_step() -> PublishingStep {
  {
    name: "Empty",
    kind: SystemStep,
    operation: fn(context, _deploy) { Ok(context) },
  }
}

///|
fn run_publishing_step(
  step : PublishingStep,
  context : PublishingContext,
  deploy : Bool,
) -> Result[PublishingContext, String] {
  if step.kind == DeploymentStep && !deploy {
    return Ok(context)
  }
  match (step.operation)(context, deploy) {
    Ok(context) => Ok(context)
    Err(error) => Err("\{step.name}: \{error}")
  }
}

///|
pub fn group_publishing_steps(steps : Array[PublishingStep]) -> PublishingStep {
  {
    name: "Group",
    kind: SystemStep,
    operation: fn(initial, deploy) {
      let mut context = initial
      for step in steps {
        match run_publishing_step(step, context, deploy) {
          Ok(updated) => context = updated
          Err(error) => return Err(error)
        }
      }
      Ok(context)
    },
  }
}

///|
pub fn conditional_publishing_step(
  condition : Bool,
  step : PublishingStep,
) -> PublishingStep {
  if condition {
    step
  } else {
    empty_publishing_step()
  }
}

///|
/// Turns failures into a no-op and preserves the context from before the step.
pub fn optional_publishing_step(step : PublishingStep) -> PublishingStep {
  {
    name: "Optional \{step.name}",
    kind: step.kind,
    operation: fn(context, deploy) {
      match (step.operation)(context, deploy) {
        Ok(updated) => Ok(updated)
        Err(_error) => Ok(context)
      }
    },
  }
}

///|
pub fn publish_plugin(
  name : String,
  installer : (PublishingContext) -> Result[PublishingContext, String],
) -> PublishPlugin {
  { name, installer, }
}

///|
pub fn install_publish_plugin(plugin : PublishPlugin) -> PublishingStep {
  {
    name: "Install plugin '\{plugin.name}'",
    kind: GenerationStep,
    operation: fn(context, _deploy) { (plugin.installer)(context) },
  }
}

///|
/// Executes generation steps in order. Deployment steps only run when
/// `deploy=true`, matching Publish's `publish deploy` behavior.
pub fn execute_publish_pipeline(
  initial : PublishingContext,
  steps : Array[PublishingStep],
  deploy? : Bool = false,
) -> Result[PublishingContext, String] {
  let mut context = initial
  for step in steps {
    match run_publishing_step(step, context, deploy) {
      Ok(updated) => context = updated
      Err(error) => return Err(error)
    }
  }
  Ok(context)
}
