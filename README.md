# guard.nvim

Schema validation and LuaCATS type generation, in one Lua file.

`guard` validates Lua values and JSON payloads against composable guards, and
the same guards can emit LuaCATS annotations for editor type checking. An
example of this is a response schema that both rejects a malformed API payload
at runtime and gives EmmyLua the field types of a valid payload.

The module is unified: requiring the vendored file returns the library, and
running it as the main `nvim -l` script runs the schema generator.

## Vendor the file

`guard` is meant to travel with the project that uses it, in the same spirit as
a binary in `node_modules/.bin`. Vendor it at `lua/<MYPKG>/_vendor/guard.lua`
and require it from there; there is no global install to keep in sync.

An example of this is a plugin called `myplugin`:

```sh
version=v0.1.0
base="https://github.com/jrop/guard.nvim/releases/download/$version"
mkdir -p lua/myplugin/_vendor
curl -fsSLo lua/myplugin/_vendor/guard.lua "$base/guard.lua"
curl -fsSLo lua/myplugin/_vendor/guard.lua.sha256 "$base/guard.lua.sha256"
(cd lua/myplugin/_vendor && sha256sum -c guard.lua.sha256 && rm guard.lua.sha256)
```

The checksum file names `guard.lua`, so verify it from the directory that holds
the copy. The vendored file is both the runtime library and the CLI, and it has
args.nvim bundled, so no other files are needed.

## Validate a value

The examples use the vendored path from the previous section.

```lua
local g = require 'myplugin._vendor.guard'

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
local g = require 'myplugin._vendor.guard'

return {
  api = {
    User = g.object {
      name = g.string(),
      age = g.number():optional(),
    },
  },
}
```

Run the generator from the vendored copy. `--module` tells the generator which
name the schema uses for guard, so the schema's `require` resolves to the
running artifact:

```sh
nvim -l lua/myplugin/_vendor/guard.lua \
  --module myplugin._vendor.guard \
  lua/myplugin/schemas.lua
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

The generator defaults to the module name `guard`, which suits a standalone
copy. Pass `--module` for the name a target file actually requires, and repeat
the flag when a file requires guard under several names.

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
mise run test:prepare
eval "$(luarocks path)"
busted spec/guard_spec.lua
```
