# General-purpose SSG roadmap

[日本語](roadmap.ja.md)

This document compares moonbit-ssg with common content-oriented static site generators and prioritizes work beyond Swift Publish compatibility.

The target is a practical blog and documentation SSG. It is not intended to become a JavaScript application framework or to reproduce every feature of every compared project.

## Reference projects

The comparison uses the public documentation of established generators:

- [Hugo content management](https://gohugo.io/content-management/), [templates](https://gohugo.io/templates/), and [Hugo Pipes](https://gohugo.io/hugo-pipes/introduction/)
- [Jekyll documentation](https://jekyllrb.com/docs/) and [pagination](https://jekyllrb.com/docs/pagination/)
- [Eleventy documentation](https://www.11ty.dev/docs/) and [pagination](https://www.11ty.dev/docs/pagination/)
- [Zola content](https://www.getzola.org/documentation/content/overview/) and [templates](https://www.getzola.org/documentation/templates/overview/)
- [Astro content collections](https://docs.astro.build/en/guides/content-collections/)

These projects differ in scope. A feature is considered common when multiple mature generators provide it directly or treat it as a standard ecosystem capability.

## Current strengths

moonbit-ssg already has a stronger base than a minimal Markdown-to-HTML tool:

- deterministic, pinned MoonBit development environment
- Publish/Ink-compatible Markdown and frontmatter behavior
- multiple sections, nested items, and free-form pages
- path overrides and two HTML file modes
- tags and tag pages
- callback-based HTML factories
- built-in Foundation theme
- RSS, podcast feeds, and sitemap
- feed caching
- media components and YouTube embeds
- immutable content operations and composable predicates
- publishing steps and plugins
- resource copying
- Git/GitHub deployment helpers with argument-array process boundaries
- project scaffolding, generation, preview server, and deployment CLI
- an isolated compatibility adapter proven against a production blog

## Gap matrix

Status meanings:

- **Available**: suitable for normal use through a public API or generic CLI.
- **Partial**: possible only through custom MoonBit code, limited to one case, or missing expected ergonomics.
- **Missing**: no supported implementation.

| Capability | Current status | Typical mature SSG behavior | Priority |
| --- | --- | --- | --- |
| Markdown content and frontmatter | Available, but frontmatter is intentionally not full YAML | YAML/TOML/JSON or structured data | P1 |
| Multiple sections/collections and nested pages | Available | Standard | Maintain |
| Draft, future, and expiry controls | Missing | Safe publication filtering with explicit overrides | **P0** |
| Content/schema validation with source locations | Partial | Actionable file/field diagnostics, often schemas | **P0** |
| File-based layouts and partials | Partial: callback API and built-in theme only | Project-local layouts, inheritance, includes/partials | **P0** |
| Pagination | Missing | Page slices, navigation metadata, stable URLs | **P0** |
| Watch mode and live reload | Partial: one build followed by a static server | Rebuild changed content while serving | **P0** |
| Taxonomies | Partial: tags only | Configurable categories and custom taxonomies | P1 |
| Permalinks, aliases, and redirects | Partial: path override only | Aliases and generated redirect pages | P1 |
| 404 and robots.txt generation | Missing | Configurable standard site files | P1 |
| Syntax highlighting | Partial: compatibility markup for shell and Swift | Broad language support and configurable themes | P1 |
| Shortcodes/components | Partial: YouTube and library media components | Extensible project-local shortcodes | P1 |
| Data files | Missing | JSON/YAML/TOML/CSV data available to templates | P1 |
| Image processing | Missing | Resize, crop, responsive variants, metadata | P1 |
| Asset pipeline | Partial: recursive copying only | Fingerprinting, minification, Sass/CSS/JS processing | P2 |
| Incremental generation | Partial: feed cache only | Avoid rendering unchanged pages | P1 after templates |
| Multilingual sites | Missing: language metadata only | Localized content trees, URLs, fallback, feeds | P2 |
| Search index output | Missing | Optional JSON/index generation | P2 |
| Multiple custom output formats | Partial through library callbacks | HTML/JSON/XML variants per content type | P2 |
| Remote content/data | Missing | Optional fetch/build integrations | P3 |
| Git deployment | Available | Usually plugin or hosting integration | Maintain; consider extraction |
| Podcast feed/media model | Available | More than most minimal SSG cores | Maintain; consider extraction |

## Priorities

### P0 — required for credible general-purpose use

#### 1. Publication controls and validation

Add generic content metadata and build policy for:

- `draft: true`
- future-dated content
- `expiryDate`
- explicit inclusion flags for local preview and CI
- errors that include the source path and invalid field

Why first: accidentally publishing drafts or failing to publish without an understandable error is a correctness problem, not an optional convenience.

Compatibility constraint: the `tanabe1478/blog` adapter must keep its current behavior. The generic project path gets the new policy independently.

#### 2. Project-local layouts and partials

The callback factory is powerful for MoonBit developers but does not let a content author edit HTML files in a project. Add a deliberately small file-based template layer with:

- layouts for index, section, item, page, and taxonomy pages
- reusable partials
- escaped interpolation by default
- explicit raw HTML output
- loops and conditionals sufficient for navigation and lists
- clear missing-variable errors

A design note and prototype should precede implementation. Adopting a template dependency is preferable to inventing a large language unless no suitable MoonBit library exists.

#### 3. Pagination

Provide a pure pagination model before coupling it to templates:

- configurable page size
- stable first/subsequent page paths
- total pages and item ranges
- previous/next URLs
- section and taxonomy pagination
- feed behavior independent from HTML pagination

#### 4. Real development watch mode

Upgrade `run` from “generate once, then serve” to:

- monitor `site.md`, `Content`, `Resources`, and project templates
- debounce changes
- rebuild safely without overlapping writes
- keep serving the last successful output after an error
- print changed paths and actionable diagnostics
- optionally trigger browser reload later

Live reload is useful, but reliable rebuild behavior comes first.

### P1 — expected for broader blog/documentation adoption

- custom taxonomies and collections
- aliases and redirect page generation
- configurable `404.html` and `robots.txt`
- data files exposed to templates
- extensible shortcodes/components
- broader syntax highlighting through a maintained library
- image resizing and responsive image metadata
- page-level incremental cache after template dependencies are known
- stricter URL collision and duplicate output detection

### P2 — valuable, but demand-driven

- multilingual content trees and localized feeds
- CSS/JS minification and content fingerprints
- Sass or another preprocessor integration
- generated search indexes
- multiple output formats per content type
- theme packaging and discovery

### P3 — intentionally deferred

- remote CMS/data fetching in the core
- JavaScript bundling or application islands
- a full development web framework
- automatic cloud-provider deployment APIs

These are better handled by plugins or external build tools unless a concrete MoonBit use case requires core support.

## Features that may be excessive in the core

“Excessive” does not mean “remove now.” These features are useful and tested, but they are not prerequisites for a minimal general-purpose SSG:

1. **`tanabe1478/blog` byte-compatibility adapter** — valuable migration evidence, but site-specific.
2. **Podcast and rich media support** — uncommon in a minimal core.
3. **Git/GitHub deployment implementation** — many SSGs leave deployment to CI or plugins.
4. **Handwritten shell and Swift highlighting compatibility** — narrow and migration-driven.
5. **Ink-specific historical quirks** — necessary for compatibility but surprising as new-site defaults.

Near-term policy:

- keep all of them stable;
- do not let compatibility behavior become the default generic behavior;
- document boundaries;
- consider subpackages only when MoonBit package dependencies can remain acyclic and the public API is mature.

## Recommended implementation order

1. **Build policy model and diagnostics**
2. **Draft/future/expiry filtering**
3. **Pure pagination model**
4. **Template engine evaluation and design note**
5. **Project-local layouts/partials prototype**
6. **Watch/rebuild loop**
7. **Aliases, 404, robots, and collision checks**
8. **Taxonomies and data files**
9. **Highlighting and image pipeline decisions**
10. **Page-level incremental cache**

The order separates pure models from I/O and avoids building an incremental cache before template dependencies are known.

## First implementation slice

The first slice should be publication controls because it is small enough to review and important enough to protect real users.

Proposed API/model:

- preserve raw metadata;
- add parsed publication state without changing blog-specific models;
- define a `PublishBuildPolicy` with `include_drafts`, `include_future`, `include_expired`, and build time;
- filter content once before HTML, tags, RSS, podcast, and sitemap generation;
- expose the same policy through `site.md` defaults and CLI overrides.

Acceptance criteria:

1. `draft: true` content is excluded by default.
2. Future content is excluded by default using the injected `BuildDate` and timezone.
3. Expired content is excluded by default.
4. Preview flags can include each category independently.
5. Excluded items do not appear in sections, tags, RSS, podcast feeds, or sitemap.
6. Invalid dates report the source path and field.
7. The blog compatibility `build` command remains unchanged.
8. Existing generic behavior changes are documented as a pre-1.0 safety correction.

## Decision points before larger work

The following choices need explicit review before implementation:

- template syntax and dependency
- whether layouts are interpreted or compiled MoonBit
- pagination URL defaults
- filesystem watcher dependency and supported platforms
- syntax highlighting library and output stability
- image library, supported formats, and native/Wasm portability
- whether optional features remain in `src` or move to subpackages

Each decision should be recorded in a small design document before code is added.
