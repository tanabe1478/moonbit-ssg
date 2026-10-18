# Architecture

[日本語](architecture.ja.md)

## Modules and packages

In MoonBit, a repository with `moon.mod` is a module, and each directory containing `moon.pkg` is a package boundary.

This repository has three packages separated by responsibility:

```text
tanabe1478/moonbit-ssg/src       library
tanabe1478/moonbit-ssg/tests     black-box tests
tanabe1478/moonbit-ssg/cmd/main  CLI
```

`src` is intentionally not split into more directories. Parsers, content models, themes, feeds, output, cache, and pipeline operations share types and internal helpers. Splitting them now would create package-level dependency pressure and possible cycles. A component should become a subpackage only when it is sufficiently independent and its public API is stable.

## Library layers

```text
source.mbt
  frontmatter and raw metadata
      │
      ├── markdown.mbt
      │     Ink-compatible HTML conversion
      │
      ├── publish_content.mbt
      │     generic Publish content model
      │
      ├── publish_html.mbt / foundation.mbt
      │     callback HTML factory / Foundation theme
      │
      ├── build_date.mbt / publish_feed.mbt / podcast.mbt
      │     build dates, RSS, sitemap, podcast feeds
      │
      ├── output.mbt / publish_files.mbt / project.mbt
      │     filesystem output, resource copying, generic projects
      │
      ├── pipeline.mbt / deployment.mbt
      │     immutable publishing steps and deployment helpers
      │
      └── cache.mbt
            step-scoped persistent cache
```

Pure string/model transformations are kept separate from filesystem I/O. Most behavior can therefore be tested without filesystem fixtures.

## Content models

`PublishedContent` and `PublishSiteConfig` expose reusable Publish-like capabilities: multiple sections, pages, nested item paths, custom metadata, media, feeds, factories, and pipelines. New features target this layer.

The library contains no site-specific models. A site with its own output contract, such as `tanabe1478/blog`, keeps its configuration and theme in its own repository and supplies them through `PublishSiteConfig` and a custom `PublishHTMLFactory`, so its quirks do not leak into defaults for new sites.

## Immutable pipelines

`PublishingContext` contains site configuration, published content, the project root, and output path. A `PublishingStep` receives a context and returns `Result[PublishingContext, String]` rather than mutating an `inout` value or throwing an untyped exception.

Generation and deployment steps share this shape. Deployment steps are skipped unless pipeline execution explicitly enables deployment. Groups, conditional steps, optional steps, plugins, content operations, file-copy operations, and injected deployment runners compose around the same context transformation.

## Persistent cache

Cache values are stored at:

```text
.publish/Caches/<step>/<name>
```

The caller owns the cache key. If the key matches, the producer is not called. Generic project feeds use a render with a fixed build timestamp as the key, so changes to site settings, item count, body, RSS metadata, or timezone invalidate the cache while a build-time-only change does not.

RSS and podcast renderers expose cached variants. Invalid podcast metadata returns an error without replacing an existing cache entry.

## Process and credential boundary

The library does not execute interpolated shell strings. Git/GitHub deployment helpers produce `DeploymentCommand` values containing a working directory, executable, and argument array. A host-provided runner executes those commands, keeping process policy and credentials outside the library.

The CLI is the host for `run` and `deploy`:

- `run` starts Python's HTTP server through MoonBit's async process API.
- `deploy` invokes Git with argument arrays and uses library functions to preserve `.git` while synchronizing output.

Secrets must come from an SSH agent, credential manager, or CI secret storage, never project metadata.

## Test package

`tests` imports `src` as a separate package, so tests use public APIs by default.

- `*_test.mbt`: feature-oriented black-box tests
- `test_fs.mbt`: filesystem fixture helpers
- `moon.pkg`: test-only package imports

Testing observable public behavior rather than private implementation details allows internal refactoring without rewriting fixtures.

## CLI package

`cmd/main` handles argument parsing, user-facing errors, and host process execution. Scaffolding, project loading, generation, output synchronization, and rendering live in public library APIs instead of being embedded in CLI branches.

The CLI has no site-specific commands. Projects use `site.md` and the generic `generate` command, or call the library from their own MoonBit module.
