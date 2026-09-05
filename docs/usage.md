# Usage

[日本語](usage.ja.md)

This guide covers the generic project CLI and the reusable MoonBit library. For internal design details, see [Architecture](architecture.md) and the [Implementation guide](implementation.md).

## 1. Set up the repository

```sh
git clone https://github.com/tanabe1478/moonbit-ssg.git
cd moonbit-ssg
mise install
mise run check
```

All examples below run the CLI from this checkout:

```sh
mise exec -- moon run cmd/main -- COMMAND
```

## 2. Create a website

```sh
mise exec -- moon run cmd/main -- new my-site "My Site"
```

The explicit Publish-style form is also supported:

```sh
mise exec -- moon run cmd/main -- new website my-site "My Site"
```

`new` refuses to overwrite a non-empty directory. It creates:

```text
my-site/
├── .gitignore
├── site.md
├── Content/
│   ├── index.md
│   └── posts/
│       ├── index.md
│       └── first-post.md
└── Resources/
```

## 3. Configure `site.md`

`site.md` uses Publish-compatible frontmatter:

```yaml
---
url: https://example.com
name: My Site
description: Notes about MoonBit
language: en
sections: posts
favicon: images/favicon.png
tagPath: tags
output: Output
---
```

| Key | Required | Default | Meaning |
| --- | --- | --- | --- |
| `url` | yes | — | Absolute public site URL |
| `name` | yes | — | Site and feed title |
| `description` | no | empty | Site and feed description |
| `language` | no | `en` | HTML and feed language |
| `sections` | yes | — | Comma-separated section directory names |
| `image` | no | none | Default social image path |
| `favicon` | no | none | Favicon path |
| `tagPath` | no | `tags` | Tag page base path; use `none` to disable tag HTML |
| `output` | no | `Output` | Generated output directory |

The generic CLI uses the built-in Foundation theme and writes `styles.css`, `feed.rss`, and `sitemap.xml`.

## 4. Add content

A section listed in `sections` maps to a directory below `Content`:

```text
Content/
├── index.md
├── about.md
├── posts/
│   ├── index.md
│   ├── hello.md
│   └── guides/
│       └── setup.markdown
└── notes/
    └── now.md
```

- `Content/index.md` is the site index.
- A listed section such as `posts` gets a section page and item pages.
- Root Markdown files and files below non-section directories become free-form pages.
- Nested section items preserve their nested paths.
- `.md`, `.markdown`, `.txt`, and `.text` are accepted.

Typical item frontmatter:

```markdown
---
date: 2026-09-05 13:44
description: A short summary.
tags: moonbit, ssg
---
# Hello

Article body.
```

Supported metadata includes `title`, `date`, `lastModified`, `description`, `tags`, `path`, `image`, RSS overrides, audio/video fields, and podcast fields. See [Publish compatibility](compatibility.md) for the implemented capability list.

## 5. Generate and preview

```sh
mise exec -- moon run cmd/main -- generate my-site
```

For reproducible output, pass a build timestamp:

```sh
mise exec -- moon run cmd/main -- \
  generate my-site 2026-09-05T13:44:37+0900
```

The accepted format is `yyyy-MM-ddTHH:mm:ss` with an optional `+HHMM` offset. An omitted offset defaults to `+0900`.

Generate and start Python's local HTTP server:

```sh
mise exec -- moon run cmd/main -- run my-site
mise exec -- moon run cmd/main -- run my-site --port 4173
```

The default port is `8000`. Press `CTRL-C` to stop the server.

## 6. Feed cache

Persistent cache entries live below:

```text
.publish/Caches/<step>/<name>
```

The generic build reuses an RSS feed when site settings, content, RSS metadata, and timezone are unchanged. A changed build time alone does not invalidate the previous feed, matching Publish's feed cache behavior.

Library users can call:

```moonbit
@ssg.render_cached_publish_rss_feed(...)
@ssg.render_cached_publish_podcast_feed(...)
@ssg.cached_publish_value(...)
@ssg.cached_publish_result(...)
```

## 7. Deploy with Git

Add deployment settings to `site.md`:

```yaml
deploymentRemote: git@github.com:owner/site.git
deploymentBranch: pages
deploymentDirectory: .publish/Git
deploymentCommitMessage: Publish deploy
```

Then run:

```sh
mise exec -- moon run cmd/main -- deploy my-site
```

The command:

1. Generates the site.
2. Initializes or reuses the persistent deployment checkout.
3. Updates `origin` and attempts to pull the configured branch.
4. Checks out the branch or creates it when missing.
5. Replaces checkout files with generated output while preserving `.git`.
6. Adds, commits, and pushes the result.

Commands are executed as an executable plus an argument array, not as an interpolated shell command.

Do not put tokens in `site.md` or the remote URL. Use an SSH agent or Git credential manager. CI secrets should remain in the CI provider's secret storage.

## 8. Create a plugin package

Inside a MoonBit module that depends on `tanabe1478/moonbit-ssg`:

```sh
mise exec -- moon run cmd/main -- \
  new plugin path/to/image_optimizer "Image Optimizer"
```

This generates `moon.pkg` and `plugin.mbt`. The containing module remains responsible for declaring the module dependency. The command does not generate an unpublished registry dependency.

Generated plugins return `PublishPlugin` and receive an immutable `PublishingContext`:

```moonbit
pub fn image_optimizer() -> @ssg.PublishPlugin {
  @ssg.publish_plugin("Image Optimizer", fn(context) {
    Ok(context)
  })
}
```

## 9. Render one Markdown file

```sh
mise exec -- moon run cmd/main -- render-markdown Content/posts/hello.md
```

The command removes frontmatter, renders the body with Ink-compatible behavior, and writes HTML to standard output.

## 10. Use the library

Declare the package import in `moon.pkg`:

```moonbit
import {
  "tanabe1478/moonbit-ssg/src" @ssg,
}
```

Load a complete Publish directory:

```moonbit
let content = @ssg.load_published_content(
  "Content",
  ["posts", "episodes"],
)
```

Generate HTML with the Foundation factory:

```moonbit
let site : @ssg.PublishSiteConfig = {
  url: "https://example.com",
  name: "Example",
  description: "Example site",
  language: "en",
  image_path: None,
  favicon_path: Some("images/favicon.png"),
}

@ssg.generate_publish_html(
  "Output",
  content,
  @ssg.foundation_html_factory(site),
)
```

The library also exposes custom HTML factories, predicates, immutable content operations, publishing pipelines, feed and sitemap renderers, media components, file-copy steps, and injectable Git/GitHub deployment helpers. Refer to [`src/pkg.generated.mbti`](../src/pkg.generated.mbti) for exact signatures.

## 11. Build the tanabe1478/blog compatibility site

The low-level `build` command preserves the historical blog-specific output contract:

```sh
mise exec -- moon run cmd/main -- \
  build Content Resources Output
```

An optional timestamp enables deterministic migration checks:

```sh
mise exec -- moon run cmd/main -- \
  build Content Resources Output 2026-09-05T13:44:37+0900
```

New sites should use `new`, `site.md`, and `generate` instead.
