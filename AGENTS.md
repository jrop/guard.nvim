# guard.nvim - Agent Development Guide

## Project

`lua/guard.lua` is one unified file: requiring it returns the validation
library, and running it as the main `nvim -l` script runs the schema generator.
A checkout resolves the argument parser from `lua/guard/_vendor/args.lua`, and
the released artifact has that parser inlined, so one file supports both roles.

The library validates Lua values against composable guards and renders guard
schemas as LuaCATS annotations. The generator walks a target file's exported
table, writes a `.types.lua` file next to it, and exits nonzero if any target
file fails to load or run.

## Commands

All tasks use `mise`:

- `mise run fmt` - format with stylua
- `mise run fmt:check` - check formatting
- `mise run lint` - type-check with `emmylua_check` (warnings are errors)
- `mise run test` - run the suite against Neovim 0.12.6
- `mise run test:all` - run the suite against 0.10.4, 0.11.7, 0.12.6, and nightly
- `mise run test:coverage` - run the suite with line coverage of `lua/`
- `mise run ci` - `fmt:check` then `lint` then `test:all`
- `mise run release` - publish the current `v*` tag to GitHub (maintainers only)

The suite runs on the vendored test.nvim runner, so a spec file or a case
filter can be run directly with no setup:

```sh
nvim -l lua/guard/vendor/test.lua spec/guard_spec.lua --filter 'CLI'
```

## Architecture

- **`lua/guard.lua`** - the whole module. The top half defines `ParseError`,
  the `Guard` class, primitives, composites, converters, and LuaCATS
  inference. The bottom half is the CLI: argument parsing, target loading,
  namespace walking, annotation rendering, and file writing.
- **`lua/guard/_vendor/args.lua`** - vendored args.nvim v0.1.0 parser. Treat it
  as third-party code: update it from the upstream release rather than editing
  it in place.
- **`lua/guard/vendor/test.lua`** - vendored test.nvim runner and assertions,
  managed by `nvim-bundle install` from `nvim-bundle.json`. Update it with
  `nvim-bundle update test` rather than editing it in place.
- **`spec/guard_spec.lua`** - the whole test suite. The library cases build
  guards directly and assert parse results, formatted errors, or generated
  annotations. The CLI cases write a schema tree to a temporary directory, run
  `lua/guard.lua` in a child Neovim, and inspect the emitted `.types.lua` file.

## Release artifact

`mise run release` publishes one file:

- **`guard.lua`** - `lua/guard.lua` bundled with `nvim-bundle --bin`, so the
  vendored args.nvim copy is inlined and the file runs as both a CLI and a
  library.

The release task refuses an untagged `HEAD`, a dirty tree, or a tag missing
from the remote.

## Conventions

- LuaJIT; do **not** use goto.
- Stylua: single quotes, no call parentheses for simple statements, 2-space
  indent, 100-column width, sorted requires.
- Keep the library free of load-time file or module dependencies. The CLI's
  argument-parser require belongs inside `main`, not at module scope, so
  requiring guard never loads args.nvim.
- The CLI's default module name is `guard`, because the published `guard.lua`
  cannot infer the guard module's name from its own filename. Target schemas
  that use another name pass `--module`.
- Keep errors actionable and exit nonzero when a target file fails.
- Preserve the generated header: it records the source, module prefix, and the
  exact regeneration command.
