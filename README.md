# guard.nvim

Schema validation and LuaCATS type generation, in one Lua file.

`guard` validates Lua values and JSON payloads against composable guards, and
the same guards can emit LuaCATS annotations for editor type checking. An
example of this is a response schema that both rejects a malformed API payload
at runtime and gives EmmyLua the field types of a valid payload.

The module is unified: `require 'guard'` returns the library, and running the
file as the main `nvim -l` script runs the schema generator.

## Install

Each release publishes two files. Both are single-file artifacts, so neither
needs a plugin manager or a checkout.

- `guard.lua` - the library. Copy it into a directory on Neovim's `lua/`
  search path and `require 'guard'`.
- `guard` - the CLI. It has args.nvim bundled and is executable, so one
  download runs the generator.

```sh
version=v0.1.0
base="https://github.com/jrop/guard.nvim/releases/download/$version"
curl -fsSLo guard.lua "$base/guard.lua"
curl -fsSLo guard.lua.sha256 "$base/guard.lua.sha256"
curl -fsSLo guard "$base/guard"
curl -fsSLo guard.sha256 "$base/guard.sha256"
sha256sum -c guard.lua.sha256
sha256sum -c guard.sha256

mkdir -p ~/.local/share/nvim/site/lua ~/.local/bin
install -m 644 guard.lua ~/.local/share/nvim/site/lua/guard.lua
install -m 755 guard ~/.local/bin/guard
```

The checksum files accompany the artifacts under the same names plus
`.sha256`.

## Validate a value

```lua
local g = require 'guard'

local User = g.object {
  name = g.string(),
  age = g.number():optional(),
  roles = g.literal('admin', 'user', 'guest'):array { from_nil = true },
}

local user = User:parse { name = 'Alice', roles = { 'admin' } }
-- user.name == 'Alice'
-- user.age == nil
```

`parse` raises on failure. `try_parse` returns a result table instead, so the
caller can report every problem at once:

```lua
local result = User:try_parse { name = 42, age = 'old' }
if not result.ok then
  vim.notify(result:format(true), vim.log.levels.ERROR)
end
```

A typical JSON boundary parses the string first, then validates the decoded
value:

```lua
local response = g.from_json(User):try_parse(body)
if response.ok then
  local user = response.value
end
```

Guards compose with `optional`, `array`, `record`, `tuple`, `one_of`,
`all_of`, `map`, and `invariant`. Converters such as `into_number`,
`into_boolean`, and `into_json` coerce at the boundary.

## Generate types

Write a schema module that exports every guard you want as types:

```lua
-- lua/myplugin/schemas.lua
local g = require 'guard'

return {
  api = {
    User = g.object {
      name = g.string(),
      age = g.number():optional(),
    },
  },
}
```

Run the generator on it:

```sh
guard lua/myplugin/schemas.lua
# or: nvim -l guard lua/myplugin/schemas.lua
```

The generator writes `lua/myplugin/schemas.types.lua` next to the source. The
module prefix comes from the path, so the example emits
`---@class myplugin.schemas.api.User` and its fields. Use the generated name
where the schema is applied:

```lua
local schemas = require 'myplugin.schemas'

local result = g.from_json(schemas.api.User):try_parse(body)
if result.ok then
  local user = result.value -- [[@as myplugin.schemas.api.User]]
end
```

Target files normally require guard as `guard`. Pass `--module` when they use
a different name, and repeat the flag if a file requires several names:

```sh
guard --module myplugin.guard lua/myplugin/schemas.lua
```

The generator expands globs, skips existing `.types.lua` files, and exits
nonzero when a target file fails to load or run.

## Develop

All tasks use `mise`:

- `mise run fmt` - format with stylua
- `mise run fmt:check` - check formatting
- `mise run lint` - type-check with `emmylua_check` (warnings are errors)
- `mise run test` - run busted against Neovim 0.12.6
- `mise run test:fast` - run busted against the default Neovim without reinstalling nightly
- `mise run test:all` - run busted against 0.10.4, 0.11.7, 0.12.6, and nightly
- `mise run test:coverage` - test with luacov
- `mise run ci` - `fmt:check` then `lint` then `test:all`
- `mise run release` - publish the current `v*` tag to GitHub (maintainers only)

Initialize the type-stub submodule after cloning:

```sh
git submodule update --init --recursive
```

Run one spec file directly after `mise run test:prepare`:

```sh
eval $(nvimv env 0.12.6)
busted spec/guard_spec.lua
```
