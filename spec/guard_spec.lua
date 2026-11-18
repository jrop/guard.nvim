--- @diagnostic disable: duplicate-set-field
--- @diagnostic disable: missing-fields
--- @diagnostic disable: need-check-nil
--- @diagnostic disable: undefined-field

local g = require 'guard'
local t = require 'guard.vendor.test'
local assert, describe, it, after_each = t.assert, t.describe, t.it, t.after_each

--- Parse `value`, which must be invalid, and return the error.
--- @param guard guard.Guard<any>
--- @param value any
--- @return guard.ParseError
local function parse_error(guard, value)
  local _, err = guard:try_parse(value)
  return assert.ok(err, 'expected the parse to fail')
end

describe('guard', function()
  describe('module', function()
    it(
      'does not load the CLI argument parser',
      function() assert.is_nil(package.loaded['guard.vendor.args']) end
    )
  end)

  describe('primitives', function()
    describe('string()', function()
      it('should accept strings', function()
        assert.equal(g.string():parse 'hello', 'hello')
        assert.equal(g.string():parse '', '')
      end)

      it('should reject non-strings', function()
        assert.raises(function() g.string():parse(123) end)
        assert.raises(function() g.string():parse(true) end)
        assert.raises(function() g.string():parse {} end)
        assert.raises(function() g.string():parse(nil) end)
      end)

      it('should return true for is() on strings', function()
        assert.equal(g.string():is 'hello', true)
        assert.equal(g.string():is(123), false)
      end)
    end)

    describe('number()', function()
      it('should accept numbers', function()
        assert.equal(g.number():parse(42), 42)
        assert.equal(g.number():parse(3.14), 3.14)
        assert.equal(g.number():parse(-1), -1)
        assert.equal(g.number():parse(0), 0)
      end)

      it('should reject non-numbers', function()
        assert.raises(function() g.number():parse '42' end)
        assert.raises(function() g.number():parse(true) end)
        assert.raises(function() g.number():parse {} end)
      end)
    end)

    describe('integer()', function()
      it('should accept integers', function()
        assert.equal(g.integer():parse(42), 42)
        assert.equal(g.integer():parse(-100), -100)
        assert.equal(g.integer():parse(0), 0)
      end)

      it('should reject floats', function()
        assert.raises(function() g.integer():parse(3.14) end)
        assert.raises(function() g.integer():parse(1.5) end)
      end)
    end)

    describe('boolean()', function()
      it('should accept booleans', function()
        assert.equal(g.boolean():parse(true), true)
        assert.equal(g.boolean():parse(false), false)
      end)

      it('should reject non-booleans', function()
        assert.raises(function() g.boolean():parse(1) end)
        assert.raises(function() g.boolean():parse 'true' end)
        assert.raises(function() g.boolean():parse(nil) end)
      end)
    end)

    describe('nil_()', function()
      it('should accept nil', function() assert.is_nil(g.nil_():parse(nil)) end)

      it('should reject non-nil', function()
        assert.raises(function() g.nil_():parse(0) end)
        assert.raises(function() g.nil_():parse '' end)
        assert.raises(function() g.nil_():parse(false) end)
      end)
    end)

    describe('any()', function()
      it('should accept anything', function()
        assert.equal(g.any():parse 'hello', 'hello')
        assert.equal(g.any():parse(42), 42)
        assert.is_nil(g.any():parse(nil))
        local t = { a = 1 }
        assert.equal(g.any():parse(t), t)
      end)
    end)

    describe('table()', function()
      it('should accept tables', function()
        local t = { 1, 2, 3 }
        assert.equal(g.table():parse(t), t)
        assert.deep_equal(g.table():parse {}, {})
      end)

      it('should reject non-tables', function()
        assert.raises(function() g.table():parse 'table' end)
        assert.raises(function() g.table():parse(nil) end)
      end)
    end)

    describe('func()', function()
      it('should accept functions', function()
        local f = function() end
        assert.equal(g.func():parse(f), f)
      end)

      it('should reject non-functions', function()
        assert.raises(function() g.func():parse 'function' end)
        assert.raises(function() g.func():parse {} end)
      end)
    end)

    describe('userdata()', function()
      it('should accept userdata', function()
        local handle = vim.uv.new_timer()
        assert.equal(g.userdata():parse(handle), handle)
        handle:close()
      end)

      it('should reject non-userdata', function()
        assert.raises(function() g.userdata():parse 'userdata' end)
        assert.raises(function() g.userdata():parse {} end)
      end)
    end)

    describe('thread()', function()
      it('should accept coroutines', function()
        local co = coroutine.create(function() end)
        assert.equal(g.thread():parse(co), co)
      end)

      it('should reject non-threads', function()
        assert.raises(function() g.thread():parse 'thread' end)
        assert.raises(function() g.thread():parse {} end)
      end)
    end)
  end)

  describe('literal()', function()
    it('should match exact values', function()
      assert.equal(g.literal('foo'):parse 'foo', 'foo')
      assert.equal(g.literal(42):parse(42), 42)
      assert.equal(g.literal(true):parse(true), true)
    end)

    it('should accept multiple literal options', function()
      local status = g.literal('active', 'inactive', 'pending')
      assert.equal(status:parse 'active', 'active')
      assert.equal(status:parse 'inactive', 'inactive')
      assert.equal(status:parse 'pending', 'pending')
    end)

    it('should reject non-matching values', function()
      assert.raises(function() g.literal('foo'):parse 'bar' end)
      assert.raises(function() g.literal(1, 2, 3):parse(4) end)
    end)
  end)

  describe('pattern()', function()
    it('should match Lua patterns', function()
      assert.equal(g.pattern('^%a+$'):parse 'hello', 'hello')
      assert.equal(g.pattern('^%d+$'):parse '123', '123')
    end)

    it('should reject non-matching strings', function()
      assert.raises(function() g.pattern('^%d+$'):parse 'abc' end)
      assert.raises(function() g.pattern('^hello$'):parse 'hello world' end)
    end)

    it('should reject non-strings', function()
      assert.raises(function() g.pattern('^%d+$'):parse(123) end)
    end)
  end)

  describe('object()', function()
    it('should validate object shape', function()
      local User = g.object {
        name = g.string(),
        age = g.number(),
      }
      local result = User:parse { name = 'Alice', age = 30 }
      assert.equal(result.name, 'Alice')
      assert.equal(result.age, 30)
    end)

    it('should allow extra keys by default (passthrough)', function()
      local User = g.object {
        name = g.string(),
      }
      local result = User:parse { name = 'Alice', extra = 'value' }
      assert.equal(result.name, 'Alice')
      assert.equal(result.extra, 'value')
    end)

    it('should reject extra keys in strict mode', function()
      local User = g.object({
        name = g.string(),
      }, { strict = true })
      assert.raises(function() User:parse { name = 'Alice', extra = 'value' } end)
    end)

    it('should reject non-tables', function()
      local User = g.object { name = g.string() }
      assert.raises(function() User:parse 'not a table' end)
      assert.raises(function() User:parse(nil) end)
    end)

    it('should report nested errors', function()
      local User = g.object {
        name = g.string(),
        age = g.number(),
      }
      local ok, err = pcall(function() User:parse { name = 123, age = 'thirty' } end)
      assert.equal(ok, false)
      assert.matches(tostring(err), 'name')
      assert.matches(tostring(err), 'age')
    end)

    it('should handle nested objects', function()
      local Address = g.object {
        city = g.string(),
        zip = g.string(),
      }
      local User = g.object {
        name = g.string(),
        address = Address,
      }
      local result = User:parse {
        name = 'Alice',
        address = { city = 'NYC', zip = '10001' },
      }
      assert.equal(result.address.city, 'NYC')
    end)

    it('should reject missing required fields', function()
      local User = g.object { name = g.string() }
      assert.raises(function() User:parse {} end)
      assert.raises(function() User:parse { name = nil } end)
    end)
  end)

  describe('record()', function()
    it('should validate uniform key/value types', function()
      local StringToNumber = g.record(g.string(), g.number())
      local result = StringToNumber:parse { a = 1, b = 2, c = 3 }
      assert.equal(result.a, 1)
      assert.equal(result.b, 2)
      assert.equal(result.c, 3)
    end)

    it('should reject invalid values', function()
      local StringToNumber = g.record(g.string(), g.number())
      assert.raises(function() StringToNumber:parse { a = 'not a number' } end)
    end)

    it('should report the key and its problem when a key fails', function()
      local StringToNumber = g.record(g.string(), g.number())
      local msg = parse_error(StringToNumber, { [1] = 10 }):format(false)
      assert.ok(msg:find('[key "1"]', 1, true), msg)
      assert.ok(msg:find('Expected string', 1, true), msg)
    end)
  end)

  describe('array()', function()
    it('should validate array items', function()
      local Numbers = g.array(g.number())
      local result = Numbers:parse { 1, 2, 3 }
      assert.deep_equal(result, { 1, 2, 3 })
    end)

    it('should work with guard:array() method', function()
      local Strings = g.string():array()
      local result = Strings:parse { 'a', 'b', 'c' }
      assert.deep_equal(result, { 'a', 'b', 'c' })
    end)

    it('should reject invalid items', function()
      local Numbers = g.array(g.number())
      assert.raises(function() Numbers:parse { 1, 'two', 3 } end)
    end)

    it('should handle empty arrays', function()
      local Numbers = g.array(g.number())
      assert.deep_equal(Numbers:parse {}, {})
    end)

    it('should report index in error', function()
      local Numbers = g.array(g.number())
      local ok, err = pcall(function() Numbers:parse { 1, 2, 'three' } end)
      assert.equal(ok, false)
      assert.matches(tostring(err), '%[3%]')
    end)

    it('should coerce nil to empty array with from_nil option', function()
      local Numbers = g.number():array { from_nil = true }
      assert.deep_equal(Numbers:parse(nil), {})
    end)
  end)

  describe('array_nonempty()', function()
    it('should accept non-empty arrays', function()
      local Numbers = g.number():array_nonempty()
      assert.deep_equal(Numbers:parse { 1 }, { 1 })
      assert.deep_equal(Numbers:parse { 1, 2, 3 }, { 1, 2, 3 })
    end)

    it('should reject empty arrays', function()
      local Numbers = g.number():array_nonempty()
      assert.raises(function() Numbers:parse {} end)
    end)
  end)

  describe('tuple()', function()
    it('should validate fixed-length tuples', function()
      local Point = g.tuple(g.number(), g.number())
      local result = Point:parse { 10, 20 }
      assert.equal(result[1], 10)
      assert.equal(result[2], 20)
    end)

    it('should validate mixed-type tuples', function()
      local Entry = g.tuple(g.string(), g.number(), g.boolean())
      local result = Entry:parse { 'key', 42, true }
      assert.equal(result[1], 'key')
      assert.equal(result[2], 42)
      assert.equal(result[3], true)
    end)

    it('should reject wrong length', function()
      local Point = g.tuple(g.number(), g.number())
      assert.raises(function() Point:parse { 1 } end)
      assert.raises(function() Point:parse { 1, 2, 3 } end)
    end)

    it('should reject wrong types', function()
      local Point = g.tuple(g.number(), g.number())
      assert.raises(function() Point:parse { 1, 'two' } end)
    end)
  end)

  describe('one_of()', function()
    it('should accept any matching guard', function()
      local StringOrNumber = g.one_of(g.string(), g.number())
      assert.equal(StringOrNumber:parse 'hello', 'hello')
      assert.equal(StringOrNumber:parse(42), 42)
    end)

    it('should reject if none match', function()
      local StringOrNumber = g.one_of(g.string(), g.number())
      assert.raises(function() StringOrNumber:parse(true) end)
      assert.raises(function() StringOrNumber:parse {} end)
    end)

    it('should work with or_() method', function()
      local StringOrNumber = g.string():or_(g.number())
      assert.equal(StringOrNumber:parse 'hello', 'hello')
      assert.equal(StringOrNumber:parse(42), 42)
    end)
  end)

  describe('by_type()', function()
    local Dependency = g.by_type {
      string = g.string(),
      table = g.object({ repo = g.string(), exclude = g.string():array():optional() }, {
        strict = true,
      }),
    }

    it('should parse with the guard for the Lua type of the value', function()
      assert.equal(Dependency:parse 'me/dep', 'me/dep')
      assert.deep_equal(Dependency:parse { repo = 'me/dep' }, { repo = 'me/dep' })
    end)

    it('should report only the problems of the chosen guard', function()
      local msg = assert.raises(function() Dependency:parse { repo = 'me/dep', exclude = 'x' } end)
      assert.matches(msg, '`%.exclude`: Expected array')
      assert.ok(not msg:find('Expected string', 1, true), msg)
    end)

    it('should name every accepted type when none is chosen', function()
      local msg = assert.raises(function() Dependency:parse(42) end)
      assert.matches(msg, 'Expected string or table')
    end)

    it('should generate the union of its guards, in type-name order', function()
      local Value = g.by_type { table = g.string():array(), number = g.number() }
      assert.equal(Value:infer_type(), 'number|string[]')
    end)

    it('should reject a key that is not a Lua type name', function()
      -- The type checker rejects the key too; this covers callers it never sees.
      --- @diagnostic disable-next-line: param-type-mismatch
      assert.raises(function() g.by_type { str = g.string() } end, 'not a Lua type: str')
    end)
  end)

  describe('tagged()', function()
    local Shape = g.tagged('kind', {
      circle = { radius = g.number() },
      square = { side = g.number() },
    })

    it('should parse each variant and keep its tag', function()
      assert.deep_equal(
        Shape:parse { kind = 'circle', radius = 2 },
        { kind = 'circle', radius = 2 }
      )
      assert.deep_equal(Shape:parse { kind = 'square', side = 3 }, { kind = 'square', side = 3 })
    end)

    it('should report only the problems of the tagged variant', function()
      local msg = assert.raises(function() Shape:parse { kind = 'circle', radius = 'big' } end)
      assert.matches(msg, '`%.radius`: Expected number')
      assert.ok(not msg:find('square', 1, true), msg)
    end)

    it('should name every tag when the tag is unknown or missing', function()
      for _, value in ipairs { { kind = 'triangle' }, {} } do
        local msg = assert.raises(function() Shape:parse(value) end)
        assert.matches(msg, '`%.kind`: Expected one of: "circle", "square"')
      end
    end)

    it('should reject a value that is not a table', function()
      assert.matches(assert.raises(function() Shape:parse 'circle' end), 'Expected table')
    end)

    it('should reject a field table that declares the tag itself', function()
      assert.raises(
        function() g.tagged('kind', { circle = { kind = g.literal 'circle' } }) end,
        'variant circle declares its own `kind`'
      )
    end)

    it('should reject a variant that is not a table of fields', function()
      -- A guard is a table too, so it must be told apart from a field table.
      for _, variant in ipairs { g.object { radius = g.number() }, 42 } do
        assert.raises(
          --- @diagnostic disable-next-line: assign-type-mismatch
          function() g.tagged('kind', { circle = variant }) end,
          'variant circle must be a table of fields'
        )
      end
    end)

    it('should reject non-string tags and an empty variant table', function()
      --- @diagnostic disable-next-line: param-type-mismatch
      assert.raises(function() g.tagged('kind', { { x = g.number() } }) end, 'must be strings')
      assert.raises(function() g.tagged('kind', {}) end, 'at least one variant')
    end)

    it('should name its variant classes after their tags', function()
      local result = Shape:to_luacats 'Shape'
      assert.ok(result:find('---@class Shape.circle', 1, true), result)
      assert.ok(result:find("---@field kind 'circle'", 1, true), result)
      assert.ok(result:find("---@field kind 'square'", 1, true), result)
      assert.ok(result:find('---@alias Shape Shape.circle|Shape.square', 1, true), result)
    end)
  end)

  describe('all_of()', function()
    it('should require all guards to match', function()
      local HasName = g.object { name = g.string() }
      local HasAge = g.object { age = g.number() }
      local Person = g.all_of(HasName, HasAge)

      local result = Person:parse { name = 'Alice', age = 30 }
      assert.equal(result.name, 'Alice')
      assert.equal(result.age, 30)
    end)

    it('should reject if any guard fails', function()
      local HasName = g.object { name = g.string() }
      local HasAge = g.object { age = g.number() }
      local Person = g.all_of(HasName, HasAge)

      assert.raises(function()
        Person:parse { name = 'Alice' } -- missing age
      end)
    end)

    it('should work with and_() method', function()
      local HasName = g.object { name = g.string() }
      local HasAge = g.object { age = g.number() }
      local Person = HasName:and_(HasAge)

      local result = Person:parse { name = 'Alice', age = 30 }
      assert.equal(result.name, 'Alice')
    end)
  end)

  describe('instance_of()', function()
    it('should accept values with the metatable', function()
      local Point = {}
      local point = setmetatable({ x = 1, y = 2 }, Point)
      assert.equal(g.instance_of(Point, 'Point'):parse(point), point)
    end)

    it('should reject tables with another metatable', function()
      local Point = {}
      assert.raises(function() g.instance_of(Point, 'Point'):parse {} end)
      assert.raises(function() g.instance_of(Point, 'Point'):parse(setmetatable({}, {})) end)
    end)

    it('should reject non-tables', function()
      assert.raises(function() g.instance_of({}, 'Point'):parse 'Point' end)
    end)

    it('should name the metatable and the generic fallback in errors', function()
      local Point = {}
      local named_msg = parse_error(g.instance_of(Point, 'Point'), {}):format(false)
      assert.ok(named_msg:find('Expected instance of Point', 1, true), named_msg)

      local unnamed_msg = parse_error(g.instance_of(Point), {}):format(false)
      assert.ok(unnamed_msg:find('Expected instance of specific metatable', 1, true), unnamed_msg)
    end)
  end)

  describe('optional()', function()
    it('should allow nil', function()
      local MaybeString = g.string():optional()
      assert.equal(MaybeString:parse 'hello', 'hello')
      assert.is_nil(MaybeString:parse(nil))
    end)

    it('should still reject wrong types', function()
      local MaybeString = g.string():optional()
      assert.raises(function() MaybeString:parse(123) end)
    end)
  end)

  describe('default()', function()
    it('should decode nil as a fresh value from make', function()
      local Tags = g.string():array():default(function() return {} end)
      local first, second = Tags:parse(nil), Tags:parse(nil)
      assert.deep_equal(first, {})
      first[1] = 'mutated'
      assert.deep_equal(second, {})
    end)

    it('should parse a present value with the inner guard', function()
      local Tags = g.string():array():default(function() return {} end)
      assert.deep_equal(Tags:parse { 'a' }, { 'a' })
      assert.raises(function() Tags:parse { 1 } end)
    end)

    it('should generate a required field of the inner type', function()
      local Config = g.object {
        tags = g.string():array():default(function() return {} end),
      }
      local annotations = Config:to_luacats 'Config'
      assert.matches(annotations, '---@field tags string%[%]')
      assert.ok(not annotations:find('tags?', 1, true), annotations)
    end)
  end)

  describe('map()', function()
    it('should transform the value', function()
      local Doubled = g.number():map(function(x) return g.ok(x * 2) end)
      assert.equal(Doubled:parse(42), 84)
    end)

    it('should chain transformations', function()
      local Processed = g.string()
        :map(function(s) return g.ok(s:upper()) end)
        :map(function(s) return g.ok(s .. '!') end)
      assert.equal(Processed:parse 'hello', 'HELLO!')
    end)

    it('should allow returning errors', function()
      local Positive = g.number():map(function(x)
        if x <= 0 then return g.err(x, { { path = {}, message = 'Must be positive' } }) end
        return g.ok(x)
      end)
      assert.equal(Positive:parse(42), 42)
      assert.raises(function() Positive:parse(-1) end)
    end)
  end)

  describe('invariant()', function()
    it('should pass when predicate is true', function()
      local Positive = g.number():invariant(function(x) return x > 0 end, 'Must be positive')
      assert.equal(Positive:parse(42), 42)
    end)

    it('should fail when predicate is false', function()
      local Positive = g.number():invariant(function(x) return x > 0 end, 'Must be positive')
      assert.raises(function() Positive:parse(-1) end)
    end)
  end)

  describe('into_number()', function()
    it('should pass through numbers', function()
      assert.equal(g.into_number():parse(42), 42)
      assert.equal(g.into_number():parse(3.14), 3.14)
    end)

    it('should parse numeric strings', function()
      assert.equal(g.into_number():parse '42', 42)
      assert.equal(g.into_number():parse '3.14', 3.14)
      assert.equal(g.into_number():parse '-100', -100)
    end)

    it('should reject non-numeric strings', function()
      assert.raises(function() g.into_number():parse 'hello' end)
      assert.raises(function() g.into_number():parse '' end)
    end)

    it('should reject other types', function()
      assert.raises(function() g.into_number():parse(true) end)
      assert.raises(function() g.into_number():parse {} end)
    end)
  end)

  describe('into_string()', function()
    it(
      'should pass through strings',
      function() assert.equal(g.into_string():parse 'hello', 'hello') end
    )

    it('should convert numbers to strings', function()
      assert.equal(g.into_string():parse(42), '42')
      assert.equal(g.into_string():parse(3.14), '3.14')
    end)

    it('should convert booleans to strings', function()
      assert.equal(g.into_string():parse(true), 'true')
      assert.equal(g.into_string():parse(false), 'false')
    end)

    it('should reject values with no string form', function()
      assert.raises(function() g.into_string():parse {} end)
      assert.raises(function()
        g.into_string():parse(function() end)
      end)
    end)
  end)

  describe('into_boolean()', function()
    it('should pass through booleans', function()
      assert.equal(g.into_boolean():parse(true), true)
      assert.equal(g.into_boolean():parse(false), false)
    end)

    it('should parse truthy strings', function()
      assert.equal(g.into_boolean():parse 'true', true)
      assert.equal(g.into_boolean():parse 'TRUE', true)
      assert.equal(g.into_boolean():parse '1', true)
      assert.equal(g.into_boolean():parse 'yes', true)
    end)

    it('should parse falsy strings', function()
      assert.equal(g.into_boolean():parse 'false', false)
      assert.equal(g.into_boolean():parse 'FALSE', false)
      assert.equal(g.into_boolean():parse '0', false)
      assert.equal(g.into_boolean():parse 'no', false)
      assert.equal(g.into_boolean():parse '', false)
    end)

    it('should convert numbers to booleans', function()
      assert.equal(g.into_boolean():parse(1), true)
      assert.equal(g.into_boolean():parse(-1), true)
      assert.equal(g.into_boolean():parse(0), false)
    end)

    it('should reject strings that are not boolean words', function()
      assert.raises(function() g.into_boolean():parse 'maybe' end)
    end)

    it('should reject values with no boolean form', function()
      assert.raises(function() g.into_boolean():parse {} end)
      assert.raises(function()
        g.into_boolean():parse(function() end)
      end)
    end)
  end)

  describe('from_json()', function()
    it('should parse JSON strings', function()
      local JsonObject = g.from_json(g.object {
        name = g.string(),
        value = g.number(),
      })
      local result = JsonObject:parse '{"name":"test","value":42}'
      assert.equal(result.name, 'test')
      assert.equal(result.value, 42)
    end)

    it('should reject invalid JSON', function()
      local JsonObject = g.from_json(g.any())
      assert.raises(function() JsonObject:parse 'not valid json' end)
    end)

    it('should validate parsed JSON against guard', function()
      local JsonNumber = g.from_json(g.number())
      assert.equal(JsonNumber:parse '42', 42)
      assert.raises(function() JsonNumber:parse '"not a number"' end)
    end)
  end)

  describe('into_json()', function()
    it('should serialize to JSON', function()
      local result = g.into_json():parse { name = 'test', value = 42 }
      -- Decode to verify (order may vary)
      local decoded = vim.json.decode(result)
      assert.equal(decoded.name, 'test')
      assert.equal(decoded.value, 42)
    end)

    it('should serialize primitives', function()
      assert.equal(g.into_json():parse(42), '42')
      assert.equal(g.into_json():parse 'hello', '"hello"')
      assert.equal(g.into_json():parse(true), 'true')
    end)

    it('should reject values that JSON cannot serialize', function()
      assert.raises(function()
        g.into_json():parse(function() end)
      end)
    end)
  end)

  describe('real-world examples', function()
    it('should validate a user profile', function()
      local UserProfile = g.object {
        id = g.into_number(),
        username = g.string():invariant(function(s) return #s >= 3 end, 'Min 3 chars'),
        email = g.pattern '^.+@.+%..+$',
        roles = g.literal('admin', 'user', 'guest'):array(),
        settings = g.object({
          theme = g.literal('light', 'dark'):optional(),
          notifications = g.boolean():optional(),
        }):optional(),
      }

      local result = UserProfile:parse {
        id = '123',
        username = 'alice',
        email = 'alice@example.com',
        roles = { 'admin', 'user' },
        settings = {
          theme = 'dark',
          notifications = true,
        },
      }

      assert.equal(result.id, 123) -- coerced from string
      assert.equal(result.username, 'alice')
      assert.deep_equal(result.roles, { 'admin', 'user' })
      assert.equal(result.settings.theme, 'dark')
    end)

    it('should validate API response', function()
      local ApiResponse = g.object {
        status = g.literal('ok', 'error'),
        data = g.any():optional(),
        error = g.string():optional(),
      }

      local success = ApiResponse:parse { status = 'ok', data = { items = {} } }
      assert.equal(success.status, 'ok')

      local failure = ApiResponse:parse { status = 'error', error = 'Not found' }
      assert.equal(failure.status, 'error')
      assert.equal(failure.error, 'Not found')
    end)

    it('should validate config with defaults via map', function()
      local Config = g.object({
        port = g.into_number():optional(),
        host = g.string():optional(),
      }):map(
        function(cfg)
          return g.ok {
            port = cfg.port or 8080,
            host = cfg.host or 'localhost',
          }
        end
      )

      local result = Config:parse {}
      assert.equal(result.port, 8080)
      assert.equal(result.host, 'localhost')

      local custom = Config:parse { port = '3000' }
      assert.equal(custom.port, 3000)
      assert.equal(custom.host, 'localhost')
    end)
  end)

  describe('error messages', function()
    it('should include path for nested object errors', function()
      local User = g.object {
        profile = g.object {
          name = g.string(),
        },
      }
      local err = parse_error(User, { profile = { name = 123 } })
      local msg = err:format(false)
      -- Path should show .profile.name
      assert.matches(msg, '%.profile%.name')
      assert.matches(msg, 'Expected string')
    end)

    it('should include index for array errors', function()
      local Numbers = g.array(g.number())
      local err = parse_error(Numbers, { 1, 2, 'bad', 4 })
      local msg = err:format(false)
      assert.matches(msg, '%[3%]')
      assert.matches(msg, 'Expected number')
    end)

    it('should collect multiple errors', function()
      local User = g.object {
        name = g.string(),
        age = g.number(),
        email = g.string(),
      }
      local err = parse_error(User, { name = 123, age = 'old', email = false })
      local msg = err:format(false)
      -- Should report all 3 problems
      assert.matches(msg, '3 problems')
      assert.matches(msg, '%.name')
      assert.matches(msg, '%.age')
      assert.matches(msg, '%.email')
    end)

    it('should show deeply nested paths', function()
      local Schema = g.object {
        level1 = g.object {
          level2 = g.object {
            level3 = g.array(g.object {
              value = g.number(),
            }),
          },
        },
      }
      local err = parse_error(Schema, {
        level1 = {
          level2 = {
            level3 = {
              { value = 1 },
              { value = 'bad' },
            },
          },
        },
      })
      local msg = err:format(false)
      -- Should show full path: .level1.level2.level3[2].value
      assert.matches(msg, '%.level1%.level2%.level3%[2%]%.value')
    end)

    it('should show actual values in verbose mode', function()
      local guard = g.number()
      local err = parse_error(guard, 'not a number')
      local verbose_msg = err:format(true)
      assert.matches(verbose_msg, 'got:')
      assert.matches(verbose_msg, 'not a number')
    end)

    it('should fall back to tostring when JSON cannot encode the value', function()
      local value = function() end
      local problems = { { path = {}, message = 'Expected number', actual = value } }
      local msg = g.ParseError.new(value, problems):format(true)
      assert.ok(msg:find('got:', 1, true), msg)
      assert.ok(msg:find('function:', 1, true), msg)
    end)

    it('should format ParseError nicely', function()
      local User = g.object { name = g.string() }
      local err = parse_error(User, { name = 123 })
      local msg = tostring(err)
      -- Should have header
      assert.matches(msg, 'Validation failed')
      -- Should have numbered list
      assert.matches(msg, '1%.')
      -- Should show path in backticks
      assert.matches(msg, '`%.name`')
    end)

    it('should handle array of objects with multiple errors', function()
      local Users = g.array(g.object {
        name = g.string(),
        age = g.number(),
      })
      local err = parse_error(Users, {
        { name = 'Alice', age = 30 },
        { name = 123, age = 'old' },
        { name = 'Charlie', age = 25 },
      })
      local msg = err:format(false)
      -- Should report errors for item [2]
      assert.matches(msg, '%[2%]%.name')
      assert.matches(msg, '%[2%]%.age')
      -- Should be 2 problems
      assert.matches(msg, '2 problems')
    end)

    it('should show pattern in pattern error', function()
      local guard = g.pattern '^%d%d%d%-%d%d%d%d$'
      local err = parse_error(guard, 'invalid')
      local msg = err:format(false)
      assert.matches(msg, 'pattern')
    end)

    it('should show expected literals in literal error', function()
      local guard = g.literal('red', 'green', 'blue')
      local err = parse_error(guard, 'yellow')
      local msg = err:format(false)
      assert.matches(msg, 'red')
      assert.matches(msg, 'green')
      assert.matches(msg, 'blue')
    end)
  end)

  describe('try_parse()', function()
    it('should return the value and no error on success', function()
      local value, err = g.string():try_parse 'hello'
      assert.equal(value, 'hello')
      assert.is_nil(err)
    end)

    it('should return nil and a ParseError on failure', function()
      local value, err = g.string():try_parse(123)
      assert.is_nil(value)
      assert.equal(getmetatable(err), g.ParseError)
      --- @cast err guard.ParseError
      assert.equal(#err.problems, 1)
      assert.equal(tostring(err), 'Validation failed (1 problem):\n  1. `(root)`: Expected string')
    end)

    it('should tell a valid nil apart from a failure by the error', function()
      local value, err = g.string():optional():try_parse(nil)
      assert.is_nil(value)
      assert.is_nil(err)
    end)

    it('should always give a failure at least one problem', function()
      local Opaque = g.Guard.new(nil, function(x)
        return { ok = false, actual = x } --[[@as guard.ParseResult<any>]]
      end)
      local _, err = Opaque:try_parse 'x'
      --- @cast err guard.ParseError
      assert.equal(err.problems[1].message, 'Validation failed')
    end)
  end)

  describe('is() vs matches()', function()
    it('is() returns false for coerced values', function()
      -- into_number coerces '42' to 42, so is() should be false
      assert.equal(g.into_number():is '42', false)
      -- but for actual numbers, is() should be true
      assert.equal(g.into_number():is(42), true)
    end)

    it('matches() returns true for coercible values', function()
      assert.equal(g.into_number():matches '42', true)
      assert.equal(g.into_number():matches(42), true)
    end)

    it('is() is stricter than matches()', function()
      local guard = g.into_string()
      -- 42 can be coerced to '42'
      assert.equal(guard:matches(42), true)
      -- but 42 is not already a string
      assert.equal(guard:is(42), false)
      -- 'hello' is already a string
      assert.equal(guard:is 'hello', true)
    end)
  end)

  describe('LuaCATS generation', function()
    describe('to_luacats()', function()
      it('should generate alias for primitives', function()
        assert.equal(g.string():to_luacats 'MyString', '---@alias MyString string')
        assert.equal(g.number():to_luacats 'MyNumber', '---@alias MyNumber number')
        assert.equal(g.boolean():to_luacats 'MyBool', '---@alias MyBool boolean')
        assert.equal(g.integer():to_luacats 'MyInt', '---@alias MyInt integer')
      end)

      it('should generate union for literals', function()
        local status = g.literal('active', 'inactive', 'pending')
        local result = status:to_luacats 'Status'
        assert.matches(result, "'active'")
        assert.matches(result, "'inactive'")
        assert.matches(result, "'pending'")
        assert.matches(result, '|')
      end)

      it('should generate class for objects', function()
        local User = g.object {
          name = g.string(),
          age = g.number(),
        }
        local result = User:to_luacats 'User'
        assert.matches(result, '---@class User')
        assert.matches(result, '---@field name string')
        assert.matches(result, '---@field age number')
      end)

      it('should mark optional fields with ?', function()
        local User = g.object {
          name = g.string(),
          nickname = g.string():optional(),
        }
        local result = User:to_luacats 'User'
        assert.matches(result, '---@field name string')
        assert.matches(result, '---@field nickname%? string')
        -- Ensure we don't have double ? (the old bug)
        assert.is_nil(result:match 'string%?')
      end)

      it('should generate array types', function()
        local Numbers = g.array(g.number())
        assert.equal(Numbers:to_luacats 'Numbers', '---@alias Numbers number[]')
      end)

      it('should generate nested class for nested objects', function()
        local User = g.object {
          profile = g.object {
            bio = g.string(),
          },
        }
        local result = User:to_luacats 'User'
        -- Should have both classes
        assert.matches(result, '---@class User')
        assert.matches(result, '---@class User_profile')
        assert.matches(result, '---@field bio string')
      end)

      it('should generate record types', function()
        local StringMap = g.record(g.string(), g.number())
        local result = StringMap:to_luacats 'StringMap'
        assert.matches(result, 'table<string, number>')
      end)

      it('should generate union for one_of', function()
        local StringOrNumber = g.one_of(g.string(), g.number())
        local result = StringOrNumber:to_luacats 'StringOrNumber'
        assert.matches(result, 'string|number')
      end)

      it('should keep the alias of a union of generated classes', function()
        local Event = g.one_of(g.object { x = g.number() }, g.string())
        local result = Event:to_luacats 'Event'
        assert.ok(result:find('---@class Event_alt1', 1, true), result)
        assert.ok(result:find('---@alias Event Event_alt1|string', 1, true), result)
      end)

      it('should parenthesize a union array item', function()
        local Values = g.one_of(g.string(), g.number()):array()
        assert.equal(Values:infer_type(), '(string|number)[]')
      end)

      it('should generate tuple types', function()
        local Point = g.tuple(g.number(), g.number())
        local result = Point:to_luacats 'Point'
        assert.matches(result, '%[number, number%]')
      end)

      it('should handle complex nested structures', function()
        local ApiResponse = g.object {
          status = g.literal('ok', 'error'),
          data = g.object({
            items = g.object({
              id = g.number(),
              name = g.string(),
            }):array(),
          }):optional(),
        }
        local result = ApiResponse:to_luacats 'ApiResponse'

        -- Should have all classes
        assert.matches(result, '---@class ApiResponse')
        assert.matches(result, "'ok'|'error'")
        assert.matches(result, '---@field items')
      end)
    end)

    describe('infer_type()', function()
      it('should return type string for primitives', function()
        assert.equal(g.string():infer_type(), 'string')
        assert.equal(g.number():infer_type(), 'number')
        assert.equal(g.boolean():infer_type(), 'boolean')
        assert.equal(g.integer():infer_type(), 'integer')
        assert.equal(g.table():infer_type(), 'table')
        assert.equal(g.func():infer_type(), 'function')
        assert.equal(g.userdata():infer_type(), 'userdata')
        assert.equal(g.thread():infer_type(), 'thread')
        assert.equal(g.any():infer_type(), 'any')
        assert.equal(g.nil_():infer_type(), 'nil')
      end)

      it('should return array notation for arrays', function()
        assert.equal(g.string():array():infer_type(), 'string[]')
        assert.equal(g.number():array():infer_type(), 'number[]')
      end)

      it(
        'should return optional notation',
        function() assert.equal(g.string():optional():infer_type(), 'string?') end
      )

      it('should preserve type through invariant', function()
        local Positive = g.number():invariant(function(x) return x > 0 end, 'Must be positive')
        assert.equal(Positive:infer_type(), 'number')
      end)

      it('should preserve the inner type through map', function()
        local Doubled = g.number():map(function(x) return g.ok(x * 2) end)
        assert.equal(Doubled:infer_type(), 'number')
      end)

      it('should use the first guard for all_of', function()
        assert.equal(g.all_of(g.string(), g.pattern '^x'):infer_type(), 'string')
        assert.equal(g.all_of():infer_type(), 'any')
      end)

      it('should name instance_of types', function()
        local Point = {}
        assert.equal(g.instance_of(Point, 'Point'):infer_type(), 'Point')
        assert.equal(g.instance_of(Point):infer_type(), 'specific metatable')
      end)

      it(
        'should infer literal unions and fall back to any for other values',
        function() assert.equal(g.literal(1, true, {}):infer_type(), '1|true|any') end
      )

      it('should fall back to any when a schema has no inferable metadata', function()
        local function opaque(schema)
          return g.Guard.new(schema, function(x) return g.ok(x) end)
        end
        assert.equal(opaque({ type = 'optional' }):infer_type(), 'any?')
        assert.equal(opaque({ type = 'array' }):infer_type(), 'any[]')
        assert.equal(opaque({ type = 'map' }):infer_type(), 'any')
        assert.equal(opaque({ type = 'custom' }):infer_type(), 'any')
        assert.equal(opaque({ type = 'unknown' }):infer_type(), 'any')
      end)
    end)

    describe('_schema metadata', function()
      it('should be present on primitives', function()
        assert.equal(g.string()._schema.type, 'string')
        assert.equal(g.number()._schema.type, 'number')
        assert.equal(g.boolean()._schema.type, 'boolean')
      end)

      it('should be present on composites', function()
        local obj = g.object { name = g.string() }
        assert.equal(obj._schema.type, 'object')
        assert.not_equal(obj._schema.fields, nil)
        assert.not_equal(obj._schema.fields.name, nil)
      end)

      it('should be present on arrays', function()
        local arr = g.string():array()
        assert.equal(arr._schema.type, 'array')
        assert.not_equal(arr._schema.item_guard, nil)
      end)

      it('should store literal values', function()
        local lit = g.literal('a', 'b', 'c')
        assert.equal(lit._schema.type, 'literal')
        assert.deep_equal(lit._schema.values, { 'a', 'b', 'c' })
      end)
    end)
  end)
end)

--- Black-box CLI tests. Every case writes a small schema tree to a temporary
--- directory, runs the CLI in a child Neovim, and inspects the emitted
--- `.types.lua` file.

--- Temporary paths created by the current test, removed in after_each.
local created = {}

--- @param path string
local function track(path) created[#created + 1] = path end

--- Write `files` (relative path -> contents) into a fresh temporary directory.
--- @param files table<string, string>
--- @return string root
local function fixture(files)
  local root = vim.fn.tempname()
  track(root)
  vim.fn.mkdir(root, 'p')
  for rel, content in pairs(files) do
    local path = root .. '/' .. rel
    vim.fn.mkdir(vim.fs.dirname(path), 'p')
    local f = assert(io.open(path, 'wb'))
    f:write(content)
    f:close()
  end
  return root
end

--- @param path string
--- @return string
local function slurp(path)
  local f = assert(io.open(path, 'rb'))
  local content = f:read '*a'
  f:close()
  return content
end

--- Run the CLI in a child Neovim, so every test exercises the same entry point
--- a user does.
--- @param argv string[]
--- @return vim.SystemCompleted
local function cli(argv) return t.Nvim.script('lua/guard.lua', argv) end

--- @param argv string[]
--- @return vim.SystemCompleted
local function run_ok(argv)
  local proc = cli(argv)
  assert.equal(proc.code, 0, proc.stderr)
  return proc
end

--- @param argv string[]
--- @param pattern string
local function run_fail(argv, pattern)
  local proc = cli(argv)
  assert.equal(proc.code, 1, proc.stdout)
  local stderr = proc.stderr or ''
  assert.ok(stderr:find(pattern, 1, true), ('expected %q in error %q'):format(pattern, stderr))
  return proc
end

--- @param path string
--- @return string
local function types_path(path) return (path:gsub('%.lua$', '.types.lua')) end

local SCHEMA = [[
local g = require 'guard'

return {
  api = {
    User = g.object {
      name = g.string(),
      age = g.number():optional(),
    },
  },
  Status = g.literal('ok', 'error'),
}
]]

--- A tagged union that is registered under its own name and also referenced
--- from another schema's field.
local TAGGED_SCHEMA = [[
local g = require 'guard'

local Shape = g.tagged('kind', {
  circle = { radius = g.number() },
  square = { side = g.number() },
})

return {
  Shape = Shape,
  Doc = g.object { shape = Shape },
}
]]

describe('guard CLI', function()
  after_each(function()
    for _, path in ipairs(created) do
      vim.fn.delete(path, 'rf')
    end
    created = {}
  end)

  describe('arguments', function()
    it(
      'rejects a missing schema file',
      function() run_fail({}, 'missing schema file (for example: lua/foo/schemas.lua)') end
    )

    it(
      'rejects an unknown option',
      function() run_fail({ '--nope', 'schemas.lua' }, 'unknown or unexpected option: --nope') end
    )

    it(
      'rejects an option with no value',
      function() run_fail({ '--module' }, 'option requires argument: --module') end
    )

    it('returns help without generating', function()
      for _, flag in ipairs { '--help', '-h' } do
        local proc = run_ok { flag }
        local stdout = proc.stdout or ''
        assert.ok(stdout:find('Usage: guard', 1, true), stdout)
        assert.ok(stdout:find('--module', 1, true), stdout)
      end
    end)

    it('prints both versions', function()
      for _, flag in ipairs { '--version', '-V' } do
        local proc = run_ok { flag }
        local stdout = proc.stdout or ''
        assert.ok(stdout:match '^guard %d+%.%d+%.%d+ %(Neovim %d+%.%d+%.%d+', stdout)
      end
    end)

    it('accepts an inline long-option value', function()
      local root = fixture {
        ['lua/schemas.lua'] = "local g = require 'custom.guard'\nreturn { Answer = g.integer() }\n",
      }
      run_ok {
        '--module=custom.guard',
        root .. '/lua/schemas.lua',
      }
      local generated = slurp(types_path(root .. '/lua/schemas.lua'))
      assert.ok(generated:find('---@alias schemas.Answer integer', 1, true), generated)
    end)
  end)

  describe('generation', function()
    it('writes annotations next to the schema file', function()
      local root = fixture { ['lua/schemas.lua'] = SCHEMA }
      local src = root .. '/lua/schemas.lua'
      local proc = run_ok { src }

      assert.ok(
        (proc.stdout or ''):find('Generated: ' .. types_path(src) .. ' (2 types)', 1, true),
        proc.stdout
      )

      local generated = slurp(types_path(src))
      assert.ok(generated:find('---@class schemas.api.User', 1, true), generated)
      assert.ok(generated:find('---@field name string', 1, true), generated)
      assert.ok(generated:find('---@field age? number', 1, true), generated)
      assert.ok(generated:find("---@alias schemas.Status 'ok'|'error'", 1, true), generated)
    end)

    it('records the regeneration command in the header', function()
      local root = fixture { ['lua/schemas.lua'] = SCHEMA }
      local src = root .. '/lua/schemas.lua'
      run_ok { src }

      local generated = slurp(types_path(src))
      assert.ok(generated:find('-- To regenerate, run: nvim -l ', 1, true), generated)
      assert.ok(generated:find(src, 1, true), generated)
    end)

    it('records a custom module in the regeneration command', function()
      local root = fixture {
        ['lua/schemas.lua'] = "local g = require 'custom.guard'\nreturn { Answer = g.integer() }\n",
      }
      local src = root .. '/lua/schemas.lua'
      run_ok { '--module', 'custom.guard', src }

      local generated = slurp(types_path(src))
      assert.ok(generated:find('--module custom.guard', 1, true), generated)
    end)

    it('injects every requested module name', function()
      local root = fixture {
        ['lua/schemas.lua'] = table.concat({
          "local a = require 'guard'",
          "local b = require 'my.guard'",
          'return {',
          '  A = a.string(),',
          '  B = b.number(),',
          '}',
        }, '\n'),
      }
      local src = root .. '/lua/schemas.lua'
      run_ok { '--module', 'guard', '--module', 'my.guard', src }

      local generated = slurp(types_path(src))
      assert.ok(generated:find('---@alias schemas.A string', 1, true), generated)
      assert.ok(generated:find('---@alias schemas.B number', 1, true), generated)
    end)

    it('emits a reused schema once and references it elsewhere', function()
      local root = fixture {
        ['lua/schemas.lua'] = table.concat({
          "local g = require 'guard'",
          'local User = g.object { name = g.string() }',
          'return { a = User, b = User }',
        }, '\n'),
      }
      run_ok { root .. '/lua/schemas.lua' }

      local generated = slurp(types_path(root .. '/lua/schemas.lua'))
      -- The module's own class types the file, not a schema, so it is not counted.
      local _, classes = generated:gsub('%-%-%-@class schemas%.', '')
      local _, aliases = generated:gsub('%-%-%-@alias ', '')
      assert.equal(classes, 1)
      assert.equal(aliases, 1)
    end)

    it('spells a registered union as its members where it is referenced', function()
      local root = fixture { ['lua/schemas.lua'] = TAGGED_SCHEMA }
      run_ok { root .. '/lua/schemas.lua' }

      local generated = slurp(types_path(root .. '/lua/schemas.lua'))
      local members = 'schemas.Shape.circle|schemas.Shape.square'
      assert.ok(generated:find('---@field shape ' .. members, 1, true), generated)
      assert.ok(generated:find('---@alias schemas.Shape ' .. members, 1, true), generated)
      local _, circles = generated:gsub('%-%-%-@class schemas%.Shape%.circle\n', '')
      assert.equal(circles, 1)
    end)

    it('types the module, so require gives each guard its parse type', function()
      local root = fixture {
        ['lua/schemas.lua'] = table.concat({
          "local g = require 'guard'",
          'return {',
          '  api = { User = g.object { name = g.string() } },',
          "  ['my-key'] = g.number(),",
          '  helper = function() end,',
          '}',
        }, '\n'),
      }
      run_ok { root .. '/lua/schemas.lua' }

      local generated = slurp(types_path(root .. '/lua/schemas.lua'))
      assert.ok(generated:match '^%-%-%-@meta schemas\n', generated)
      for _, line in ipairs {
        '---@class schemas\n',
        '---@field api { User: guard.Guard<schemas.api.User> }\n',
        '---@field helper any\n',
        "---@field ['my-key'] guard.Guard<",
        '---@type schemas\nlocal M\nreturn M\n',
      } do
        assert.ok(generated:find(line, 1, true), ('missing %q in:\n%s'):format(line, generated))
      end
    end)

    -- The generated types exist to make EmmyLua narrow, so this case asks
    -- EmmyLua itself. The consumer holds one deliberate mismatch in the
    -- narrowed branch: reporting it as `number` (not `number?` or `any`) shows
    -- that `parse` returned the members and the tag check narrowed them, and
    -- any other warning means a branch failed to narrow.
    local narrowing = 'narrows a tagged union in EmmyLua, through parse and fields'
    if vim.fn.executable 'emmylua_check' == 0 then
      t.pending(narrowing)
    else
      it(narrowing, function()
        local root = fixture {
          ['.emmyrc.json'] = slurp '.emmyrc.json',
          ['lua/guard.lua'] = slurp 'lua/guard.lua',
          ['lua/schemas.lua'] = TAGGED_SCHEMA,
          ['lua/use.lua'] = table.concat({
            "local schemas = require 'schemas'",
            '',
            '---@param x unknown',
            'local function area(x)',
            '  local s = schemas.Shape:parse(x)',
            "  if s.kind == 'circle' then",
            '    ---@type string',
            '    local wrong = s.radius',
            '    return wrong',
            '  end',
            '  ---@type number',
            '  local side = s.side',
            '  return side',
            'end',
            '',
            '---@param x unknown',
            'local function first(x)',
            '  local doc = schemas.Doc:parse(x)',
            "  if doc.shape.kind ~= 'square' then return 0 end",
            '  ---@type number',
            '  local side = doc.shape.side',
            '  return side',
            'end',
            '',
            'return { area = area, first = first }',
          }, '\n'),
        }
        run_ok { root .. '/lua/schemas.lua' }

        local proc = vim.system({ 'emmylua_check', '.' }, { cwd = root, text = true }):wait()
        local out = (proc.stdout or '') .. (proc.stderr or '')
        -- The copied library is linted against the running Neovim's runtime
        -- types, which older releases lack, and `mise run lint` covers it, so
        -- only the generated file and the consumer count.
        local warnings = 0
        for file in out:gmatch 'warning: [^\n]*\n%s*%-%-> ([^:]+):' do
          if file ~= 'lua/guard.lua' then warnings = warnings + 1 end
        end
        assert.equal(warnings, 1, out)
        assert.ok(out:find('Cannot assign `number` to `string`', 1, true), out)
        assert.ok(out:find('lua/use.lua:8:', 1, true), out)
      end)
    end

    it('expands a glob and skips existing .types.lua files', function()
      local root = fixture {
        ['lua/a.lua'] = "local g = require 'guard'\nreturn { A = g.string() }\n",
        ['lua/b.lua'] = "local g = require 'guard'\nreturn { B = g.number() }\n",
        ['lua/c.types.lua'] = '-- sentinel\n',
      }
      run_ok { root .. '/lua/*.lua' }

      assert.ok((slurp(types_path(root .. '/lua/a.lua')):find('---@alias a.A string', 1, true)))
      assert.ok((slurp(types_path(root .. '/lua/b.lua')):find('---@alias b.B number', 1, true)))
      assert.equal(slurp(root .. '/lua/c.types.lua'), '-- sentinel\n')
    end)

    it('skips a file that exports no table', function()
      local root = fixture { ['lua/plain.lua'] = 'return 1\n' }
      local proc = run_ok { root .. '/lua/plain.lua' }
      assert.ok((proc.stdout or ''):find('no table exported', 1, true), proc.stdout)
      assert.is_nil(vim.uv.fs_stat(types_path(root .. '/lua/plain.lua')))
    end)
  end)

  describe('errors', function()
    it('fails when a schema file raises', function()
      local root = fixture { ['lua/broken.lua'] = "error 'boom'\n" }
      run_fail({ root .. '/lua/broken.lua' }, 'guard: error running')
    end)

    it('fails when a schema file has a syntax error', function()
      local root = fixture { ['lua/broken.lua'] = 'return {\n' }
      run_fail({ root .. '/lua/broken.lua' }, 'guard: error loading')
    end)

    it('fails when a literal path does not exist', function()
      local root = fixture {}
      run_fail({ root .. '/lua/missing.lua' }, 'guard: error loading')
    end)

    it('fails when the required module name does not match', function()
      local root = fixture {
        ['lua/schemas.lua'] = "local g = require 'custom.guard'\nreturn { A = g.string() }\n",
      }
      run_fail({ root .. '/lua/schemas.lua' }, "module 'custom.guard' not found")
    end)
  end)
end)
