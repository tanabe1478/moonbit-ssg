///|
/// A process invocation requested by a built-in deployment helper.
pub(all) struct DeploymentCommand {
  working_directory : String
  executable : String
  arguments : Array[String]
} derive(Eq, Debug)

///|
/// Git deployment settings. The working directory is persistent so its `.git`
/// repository can be reused between deployments.
pub(all) struct GitDeploymentConfiguration {
  remote : String
  branch : String
  working_directory : String
  commit_message : String
} derive(Eq, Debug)

///|
pub fn default_git_deployment_configuration(
  remote : String,
  working_directory : String,
) -> GitDeploymentConfiguration {
  {
    remote,
    branch: "master",
    working_directory,
    commit_message: "Publish deploy",
  }
}

///|
pub fn github_deployment_remote(
  repository : String,
  use_ssh? : Bool = true,
) -> String {
  if use_ssh {
    "git@github.com:\{repository}.git"
  } else {
    "https://github.com/\{repository}.git"
  }
}

///|
fn deployment_command(
  configuration : GitDeploymentConfiguration,
  arguments : Array[String],
) -> DeploymentCommand {
  {
    working_directory: configuration.working_directory,
    executable: "git",
    arguments,
  }
}

///|
fn run_deployment_command(
  runner : (DeploymentCommand) -> Result[Unit, String],
  command : DeploymentCommand,
) -> Result[Unit, String] {
  match runner(command) {
    Ok(_) => Ok(())
    Err(error) =>
      Err(
        "\{command.executable} \{command.arguments.join(" ")} failed: \{error}",
      )
  }
}

///|
fn prepare_git_deployment_directory(
  context : PublishingContext,
  configuration : GitDeploymentConfiguration,
) -> Result[Unit, String] {
  ensure_directory(configuration.working_directory) catch {
    @fs.IOError(message) => return Err(message)
  }
  for
    name in (@fs.read_dir(configuration.working_directory) catch {
      @fs.IOError(message) => return Err(message)
    }) {
    if name != ".git" {
      remove_tree(join_path(configuration.working_directory, name)) catch {
        @fs.IOError(message) => return Err(message)
      }
    }
  }
  copy_publish_files(context.output_directory, configuration.working_directory) catch {
    @fs.IOError(message) => return Err(message)
  }
  Ok(())
}

///|
/// Creates Publish's built-in Git deployment as a gated pipeline step.
///
/// Process execution is supplied by the host, keeping credentials and shell
/// policy outside the SSG library. Arguments are passed separately to avoid
/// shell interpolation.
pub fn git_deployment_step(
  configuration : GitDeploymentConfiguration,
  runner : (DeploymentCommand) -> Result[Unit, String],
) -> PublishingStep {
  deployment_step("Git (\{configuration.remote})", fn(context) {
    ensure_directory(configuration.working_directory) catch {
      @fs.IOError(message) => return Err(message)
    }
    let git_directory = join_path(configuration.working_directory, ".git")
    if !@fs.path_exists(git_directory) {
      match
        run_deployment_command(
          runner,
          deployment_command(configuration, ["init"]),
        ) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      match
        run_deployment_command(
          runner,
          deployment_command(configuration, [
            "remote",
            "add",
            "origin",
            configuration.remote,
          ]),
        ) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
    }
    match
      run_deployment_command(
        runner,
        deployment_command(configuration, [
          "remote",
          "set-url",
          "origin",
          configuration.remote,
        ]),
      ) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    // Publish deliberately ignores pull failures so first deploys can proceed.
    runner(
      deployment_command(configuration, ["pull", "origin", configuration.branch]),
    )
    |> ignore
    match
      runner(
        deployment_command(configuration, ["checkout", configuration.branch]),
      ) {
      Ok(_) => ()
      Err(_) =>
        match
          run_deployment_command(
            runner,
            deployment_command(configuration, [
              "checkout",
              "-b",
              configuration.branch,
            ]),
          ) {
          Ok(_) => ()
          Err(error) => return Err(error)
        }
    }
    match prepare_git_deployment_directory(context, configuration) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    for
      arguments in [
        ["add", "."],
        ["commit", "-a", "-m", configuration.commit_message, "--allow-empty"],
        ["push", "origin", configuration.branch],
      ] {
      match
        run_deployment_command(
          runner,
          deployment_command(configuration, arguments),
        ) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
    }
    Ok(context)
  })
}

///|
pub fn github_deployment_step(
  repository : String,
  working_directory : String,
  runner : (DeploymentCommand) -> Result[Unit, String],
  branch? : String = "master",
  use_ssh? : Bool = true,
  commit_message? : String = "Publish deploy",
) -> PublishingStep {
  git_deployment_step(
    {
      remote: github_deployment_remote(repository, use_ssh~),
      branch,
      working_directory,
      commit_message,
    },
    runner,
  )
}
