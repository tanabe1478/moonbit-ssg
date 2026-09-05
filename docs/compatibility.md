# Publish 0.9 compatibility

[日本語](compatibility.ja.md)

The reference is Swift Publish `0.9.0` at revision `1c8ad00d39c985cb5d497153241a2f1b654e0d40`.

Compatibility is tracked in two layers: the exact migration contract required by `tanabe1478/blog`, and reusable capabilities from the broader Publish framework. Swift source-level API compatibility is not a goal.

## tanabe1478/blog migration contract

Implemented:

- Ink-compatible frontmatter
- Markdown-to-HTML conversion
- YouTube modifier
- shell and Swift syntax highlighting markup
- index, posts section, item, tag list, and tag details pages
- custom theme metadata, canonical URLs, Open Graph data, and Analytics
- recursive Resources and theme stylesheet copying
- RSS 2.0
- sitemap
- clean output builds
- build timezone offset preservation

Before Swift Publish was removed from the blog repository, 88 generated files were verified byte-for-byte. Representative index, latest post, tag list, migrated post, desktop, and mobile renders were also checked with zero pixel difference. The blog now generates production output with moonbit-ssg only.

## Reusable Publish capabilities

Implemented:

- multiple-section content model
- root Markdown pages
- recursive pages below non-section directories
- nested item paths
- `.md`, `.markdown`, `.txt`, and `.text` input
- custom metadata preservation
- item `path` overrides
- RSS item properties
- audio and video metadata
- callback-based custom HTML factories
- index, section, item, page, tag list, and tag details generation
- `FoldersAndIndexFiles` and `StandAloneFiles`
- optional tag HTML generation
- configurable RSS feeds, section selection, and item predicates
- RSS GUID, link, title/body prefix, and suffix overrides
- sitemap generation for multiple sections and pages with excluded paths
- Apple Podcasts and Media RSS-compatible podcast feeds
- podcast author, category, episode, season, and explicit metadata
- audio enclosure, duration, and size validation
- composable predicates with inverse, AND, and OR
- immutable item/page add, remove, mutation, and section sorting
- ascending and descending sort order
- empty, grouped, conditional, optional, custom, generation, and deployment steps
- plugin installation and deployment gating
- file, directory-content, directory, and theme-resource copy steps
- target directory support
- favicon rendering and defaults
- audio and hosted/YouTube/Vimeo video components
- built-in Foundation renderers for every location
- Foundation stylesheet and resource writing
- injected-runner Git and GitHub deployment helpers
- executable/argument separation instead of interpolated shell commands
- website `new`, `generate`, and `run` CLI commands
- generic `site.md` configuration
- step-scoped persistent `.publish/Caches` API
- cached RSS and podcast feed rendering
- Git `deploy` CLI with persistent checkout, branch fallback, synchronization, and push
- `new plugin` package scaffolding

## Known difference

Swift Publish's `new plugin` creates a complete Swift Package with a remote package dependency. MoonBit module manifests cannot directly declare a Git dependency that is not available in the package registry. The MoonBit command therefore creates `moon.pkg` and plugin source inside an existing module. The parent module owns dependency declaration and version selection.

## Meaning of compatibility

MoonBit and Swift have different type systems, error handling, mutation models, and package managers. Compatibility means:

1. Equivalent content and configuration can produce equivalent public files.
2. Operations available in Publish pipelines have MoonBit-native alternatives.
3. Known behavioral or packaging differences are documented.

Throwing/inout Swift APIs generally become immutable functions returning `Result`. Callback factories replace Swift generic protocols where that produces a clearer MoonBit API.
