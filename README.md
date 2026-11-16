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
a binary in `node_modules/.bin`. Vendor it at `lua/<MYPKG>/vendor/guard.lua`
and require it from there; there is no global install to keep in sync.

An example of this is a plugin called `myplugin`:

```sh
version=v0.1.0
base="https://github.com/jrop/guard.nvim/releases/download/$version"
mkdir -p lua/myplugin/vendor
curl -fsSLo lua/myplugin/vendor/guard.lua "$base/guard.lua"
curl -fsSLo lua/myplugin/vendor/guard.lua.sha256 "$base/guard.lua.sha256"
(cd lua/myplugin/vendor && sha256sum -c guard.lua.sha256 && rm guard.lua.sha256)
```

The checksum file names `guard.lua`, so verify it from the directory that holds
the copy. The vendored file is both the runtime library and the CLI, and it has
args.nvim bundled, so no other files are needed.

## Validate a value

The examples use the vendored path from the previous section.

```lua
local g = require 'myplugin.vendor.guard'

local User = g.object {
  name = g.string(),
  age = g.number():optional(),
  roles = g.literal('admin', 'user', 'guest'):array { from_nil = true },
}

local user = User:parse { name = 'Alice', roles = { 'admin' } }
-- user.name == 'Alice'
-- user.age == nil
```

`parse` raises on failure, with the caller's line in the message, which suits a
value that is invalid only through a bug. Input that may be invalid, such as a
file or a user's settings, goes through `try_parse` instead. It returns the
value and `nil`, or `nil` and a `ParseError` that lists every problem:

```lua
local user, err = User:try_parse { name = 42, age = 'old' }
if err then
  vim.notify(err:format(true), vim.log.levels.ERROR)
end
```

A valid value can be `nil`, for example from an optional guard, so test `err`
rather than the value.

A typical JSON boundary parses the string first, then validates the decoded
value:

```lua
local user, err = g.from_json(User):try_parse(body)
```

Guards compose with `optional`, `default`, `array`, `record`, `tuple`,
`one_of`, `by_type`, `all_of`, `map`, and `invariant`. Converters such as
`into_number`, `into_boolean`, and `into_json` coerce at the boundary.

`default` fills in a missing value, and the generated field stays required, so
code that reads the parsed value never handles a nil:

```lua
local Config = g.object {
  ignore = g.string():array():default(function() return {} end),
}
```

`make` runs on every parse, so each result gets its own table.

`by_type` chooses one guard by the input's Lua type. When the input fails, it
reports only that guard's problems, where `one_of` reports every alternative:

```lua
local Dependency = g.by_type {
  string = g.string(), -- 'owner/repo'
  table = g.object({ repo = g.string(), ref = g.string():optional() }, { strict = true }),
}
```

## Generate types

Write a schema module that exports every guard you want as types:

```lua
-- lua/myplugin/schemas.lua
local g = require 'myplugin.vendor.guard'

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
nvim -l lua/myplugin/vendor/guard.lua \
  --module myplugin.vendor.guard \
  lua/myplugin/schemas.lua
```

The generator writes `lua/myplugin/schemas.types.lua` next to the source. The
module prefix comes from the path, so the example emits
`---@class myplugin.schemas.api.User` and its fields. Use the generated name
where the schema is applied:

```lua
local schemas = require 'myplugin.schemas'

local user, err = g.from_json(schemas.api.User):try_parse(body)
if not err then
  --- @cast user myplugin.schemas.api.User
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
