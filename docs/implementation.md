# Implementation guide

[日本語](implementation.ja.md)

This guide explains the implementation for readers learning MoonBit. For task-oriented instructions, start with the [usage guide](usage.md).

## Public functions and packages

```moonbit
pub fn version() -> String {
  "0.1.0"
}
```

- `fn` defines a function.
- `pub` makes it callable from another package.
- `-> String` is the return type.
- The final expression is returned without an explicit `return`.

String interpolation uses `\{...}`:

```moonbit
"moonbit-ssg \{version()}"
```

A package imported with an alias is accessed through `@alias`:

```moonbit
println(@ssg.banner())
```

The CLI imports the library as `@ssg`. Keeping the packages separate makes the reusable API testable without going through command-line parsing.

## Black-box tests

Files ending in `_test.mbt` contain tests. The `tests` package imports `src` like an external consumer:

```moonbit
test "the public API exposes the CLI banner" {
  inspect(@ssg.banner(), content="moonbit-ssg 0.1.0")
}
```

`inspect` compares a value with snapshot text. `debug_inspect` is useful for arrays, enums, structures, and `Result` values that derive `Debug`.

## Publish-compatible source parser

`src/source.mbt` splits Markdown into frontmatter and body:

```moonbit
pub(all) struct SourceDocument {
  metadata : Metadata
  item : ItemMetadata
  markdown : String
}
```

- `struct` defines a product type with named fields.
- `pub(all)` exports both the type and its fields.
- `String?` is an optional value represented by `Some(value)` or `None`.
- `match` handles enum variants exhaustively.
- `Array[String]` is a growable array of strings.

The parser intentionally follows Ink/Publish behavior rather than implementing general YAML:

- `key: value` entries
- comma-separated tags
- ignored empty metadata values
- lines without `:` appended to the previous value
- last duplicate key wins
- unterminated frontmatter remains ordinary Markdown

These details are fixed by black-box tests in `tests/source_test.mbt`.

## Ink-compatible Markdown rendering

`src/markdown.mbt` uses `mizchi/markdown` to build an AST, then serializes it with compatibility rules for Ink output.

A stock CommonMark renderer is not sufficient because Ink differs in areas such as:

- newlines between block elements
- spelling of `<img>`, `<hr>`, and `<br>`
- image-only paragraphs
- nested and blank-line-separated lists
- historical CRLF input
- YouTube blockquote modifiers
- HighlightJS `hljs-*` markup

Rendering dispatches over AST variants:

```moonbit
match inline {
  @markdown.Inline::Text(content~, ..) => escape_html(content)
  @markdown.Inline::Strong(children~, ..) =>
    "<strong>\{render_inlines(children, definitions)}</strong>"
}
```

- `enum` represents one of several possible variants.
- `match` selects a variant, and the compiler checks exhaustiveness.
- `content~` binds a named field to a variable with the same name.
- `..` ignores fields not needed in that branch.
- Recursive block and inline rendering handles nested lists and images inside links.

Syntax highlighting currently reproduces the shell and Swift markup required by the migrated blog fixtures. Add a fixture before expanding language support.

Use the renderer directly from the CLI:

```sh
mise exec -- moon run cmd/main -- render-markdown PATH_TO_POST.md
```

## Content loading

The generic loader in `src/publish_content.mbt` supports:

- multiple sections
- root and nested free-form pages
- nested item paths
- `.md`, `.markdown`, `.txt`, and `.text`
- custom metadata
- path and RSS overrides
- audio, video, and podcast metadata

I/O and pure construction are separate:

```moonbit
let content = @ssg.load_published_content("Content", ["posts", "episodes"])
```

`build_published_content` constructs the same model from strings, which keeps sorting, metadata, and mutation tests independent from the filesystem.

The historical blog adapter in `src/content.mbt` uses `SiteContent`. New reusable code should use `PublishedContent`.

## HTML factories and themes

`PublishHTMLFactory` stores callbacks for index, section, item, page, tag list, and tag details rendering. `generate_publish_html` maps `PublishedContent` locations to output paths and invokes those callbacks.

Two output modes are supported:

- `FoldersAndIndexFiles`: `/posts/hello/index.html`
- `StandAloneFiles`: `/posts/hello.html`

The built-in Foundation implementation consists of:

- `foundation_html_factory`
- `default_foundation_theme_configuration`
- `foundation_stylesheet`
- `write_foundation_stylesheet`

The blog-specific renderer remains separate in `src/theme.mbt` to preserve historical byte-level output without imposing its quirks on new projects.

## Feeds and sitemap

Generic feed code is split between `src/publish_feed.mbt` and `src/podcast.mbt`.

`render_publish_rss_feed` supports section selection, item predicates, maximum count, TTL, target path, GUID/link overrides, and title/body prefixes or suffixes.

`render_publish_podcast_feed` validates required audio URL, duration, and byte size, then emits Apple Podcasts and Media RSS metadata including author, owner, category, episode, season, explicit status, enclosure, and media content.

Both feeds have cached variants. They build a cache key using a fixed timestamp while preserving the requested timezone. This excludes build time from invalidation but includes rendered content and configuration.

`render_publish_sitemap` includes sections, items, and pages, supports excluded paths, and aggregates `lastModified` values.

`BuildDate` is injectable:

```moonbit
let date = @ssg.BuildDate::parse("2026-09-05T13:44:37+0900").unwrap()
```

This keeps tests deterministic while normal builds can use the current time.

## Filesystem output

Output code performs four distinct operations:

- `ensure_directory`: create parent directories in order
- `remove_tree`: remove stale output from children upward
- recursive copy helpers: preserve binary resources and paths
- `write_output_file`: create a file's parent directory and write content

`write_site_output` is the blog compatibility writer. Generic projects compose `load_published_content`, HTML generation, Foundation resources, cached RSS, and sitemap generation in `build_publish_project`.

## Persistent cache format

`cached_publish_value` and `cached_publish_result` store entries below `.publish/Caches`. Entries contain a length-prefixed caller-defined key followed by the cached value. Length-prefixing allows keys and values to contain newlines without requiring a JSON dependency.

The `Result` variant only writes after successful production. A malformed cache entry is treated as a miss.

## Immutable content operations

Publish's throwing/inout operations map to immutable MoonBit functions returning updated content:

- add item or page
- remove matching items
- mutate one item, all items, or pages
- sort items in one section
- compose predicates with inverse, AND, and OR

Failures use `Result` and preserve the previous value unless a caller explicitly accepts an updated result.

## Publishing pipeline

A `PublishingStep` contains a name, a kind, and a context transformation:

```moonbit
type operation =
  (PublishingContext) -> Result[PublishingContext, String]
```

The implementation provides empty, grouped, conditional, optional, custom, plugin-installation, generation, and deployment steps. Deployment execution is explicitly gated by the `deploy` flag.

`PublishingContext` is returned as a new value. This is the MoonBit equivalent of Swift Publish's throwing `inout` operations, not source-level Swift API compatibility.

## Git deployment

The library's built-in Git helper never runs a shell string. It asks an injected runner to execute:

```moonbit
pub(all) struct DeploymentCommand {
  working_directory : String
  executable : String
  arguments : Array[String]
}
```

The flow initializes a persistent repository, configures `origin`, tolerates an initial pull failure, checks out or creates the branch, synchronizes generated output while preserving `.git`, then adds, commits, and pushes.

The CLI uses MoonBit's async process API as a concrete host runner. Authentication remains external.

## Generic project CLI

`src/project.mbt` parses `site.md`, scaffolds websites and plugin packages, and composes the generic build. `cmd/main` is intentionally thin: it parses arguments, displays errors, and invokes library APIs.

`new plugin` generates a package inside an existing MoonBit module. It does not create a standalone dependency because MoonBit module manifests cannot point directly to a registry-external Git dependency.

## Blog compatibility adapter

The low-level command:

```sh
mise exec -- moon run cmd/main -- build Content Resources Output
```

uses the historical `tanabe1478/blog` configuration and theme contract. It exists to keep the migrated production site stable. New sites should use `site.md`, `new`, and `generate`.
