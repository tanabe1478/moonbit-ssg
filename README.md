# moonbit-ssg

[日本語](README.ja.md)

A static site generator written in MoonBit, with output and capabilities compatible with Swift Publish 0.9.

`tanabe1478/blog` now uses moonbit-ssg as its sole production generator. Before removing Swift Publish, the migration was validated against 88 generated files byte-for-byte and with pixel-identical desktop and mobile browser checks.

## Requirements

The repository manages its MoonBit toolchain with [mise](https://mise.jdx.dev/).

```sh
mise install
```

`mise.toml` pins MoonBit `0.10.11+6ff76a5f9` and verifies the SHA-256 checksums of the official toolchain and standard library archives.

The `run` command additionally requires Python 3. Git deployment requires Git and credentials supplied by your SSH agent or Git credential manager.

## Quick start

```sh
git clone https://github.com/tanabe1478/moonbit-ssg.git
cd moonbit-ssg
mise install

mise exec -- moon run cmd/main -- new my-site "My Site"
mise exec -- moon run cmd/main -- generate my-site
mise exec -- moon run cmd/main -- run my-site -p 8000
```

The generated website uses `site.md` for configuration, `Content/` for Markdown, `Resources/` for static files, and `Output/` for generated files.

See the [usage guide](docs/usage.md) for project configuration, content layout, deployment, plugins, and library examples.

## CLI overview

```text
new [website] [DIRECTORY] [NAME]  Create a Foundation website project
new plugin [DIRECTORY] [NAME]     Create a plugin package in a module
generate [ROOT] [BUILD_DATE]      Generate a generic project
run [ROOT] [-p PORT]              Generate and serve a generic project
deploy [ROOT]                     Generate and deploy a generic project
render-markdown INPUT             Render one Markdown file
build CONTENT RESOURCES OUTPUT [BUILD_DATE]
                                  Build the tanabe1478/blog-compatible site
```

Run the CLI without arguments to display its help:

```sh
mise exec -- moon run cmd/main
```

## Using the library

Import the library package from a consumer package's `moon.pkg`:

```moonbit
import {
  "tanabe1478/moonbit-ssg/src" @ssg,
}
```

Then use the public parsers and renderers:

```moonbit
let document = @ssg.parse_source(markdown)
let html = @ssg.render_markdown(document.markdown)
let content = @ssg.load_published_content("Content", ["posts", "episodes"])
```

The complete generated public interface is available in [`src/pkg.generated.mbti`](src/pkg.generated.mbti).

## Development

Run formatting checks, type checking, and all tests:

```sh
mise run check
```

Individual commands:

```sh
mise exec -- moon fmt
mise exec -- moon check
mise exec -- moon test
mise exec -- moon info
```

## Repository layout

```text
.
├── src/                 # Reusable library package
├── tests/               # Black-box library tests
├── cmd/main/            # CLI executable package
├── docs/                # Usage, design, implementation, compatibility
├── resources/           # Built-in Foundation theme resources
├── moon.mod             # Module metadata and dependencies
├── mise.toml            # Pinned toolchain and development tasks
└── README.md            # English entry point
```

A directory containing `moon.pkg` is a MoonBit package boundary. Closely related SSG components remain in one `src` package, while the CLI and black-box tests use separate packages.

## Documentation

- Usage: [English](docs/usage.md) / [日本語](docs/usage.ja.md)
- Architecture: [English](docs/architecture.md) / [日本語](docs/architecture.ja.md)
- Implementation guide: [English](docs/implementation.md) / [日本語](docs/implementation.ja.md)
- Publish 0.9 compatibility: [English](docs/compatibility.md) / [日本語](docs/compatibility.ja.md)

## License

MIT
