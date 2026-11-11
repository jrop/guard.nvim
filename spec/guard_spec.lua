--- @diagnostic disable: duplicate-set-field
--- @diagnostic disable: missing-fields
--- @diagnostic disable: need-check-nil
--- @diagnostic disable: undefined-field

local g = require 'guard'

-- Under `busted --coverage`, luacov's tick interval flushes every 100 hits, but
-- the parent test process exits through Neovim rather than Lua's os.exit, so
-- the final partial batch would be lost without this save.
if package.loaded['luacov.runner'] then
  ---@type { save_stats: fun() }
  local runner = package.loaded['luacov.runner']
  vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = function() runner.save_stats() end,
  })
end

describe('guard', function()
  describe('module', function()
    it(
      'does not load the CLI argument parser',
      function() assert.is_nil(package.loaded['guard._vendor.args']) end
    )
  end)

  describe('primitives', function()
    describe('string()', function()
      it('should accept strings', function()
        assert.are.equal('hello', g.string():parse 'hello')
        assert.are.equal('', g.string():parse '')
      end)

      it('should reject non-strings', function()
        assert.has_error(function() g.string():parse(123) end)
        assert.has_error(function() g.string():parse(true) end)
        assert.has_error(function() g.string():parse {} end)
        assert.has_error(function() g.string():parse(nil) end)
      end)

      it('should return true for is() on strings', function()
        assert.is_true(g.string():is 'hello')
        assert.is_false(g.string():is(123))
      end)
    end)

    describe('number()', function()
      it('should accept numbers', function()
        assert.are.equal(42, g.number():parse(42))
        assert.are.equal(3.14, g.number():parse(3.14))
        assert.are.equal(-1, g.number():parse(-1))
        assert.are.equal(0, g.number():parse(0))
      end)

      it('should reject non-numbers', function()
        assert.has_error(function() g.number():parse '42' end)
        assert.has_error(function() g.number():parse(true) end)
        assert.has_error(function() g.number():parse {} end)
      end)
    end)

    describe('integer()', function()
      it('should accept integers', function()
        assert.are.equal(42, g.integer():parse(42))
        assert.are.equal(-100, g.integer():parse(-100))
        assert.are.equal(0, g.integer():parse(0))
      end)

      it('should reject floats', function()
        assert.has_error(function() g.integer():parse(3.14) end)
        assert.has_error(function() g.integer():parse(1.5) end)
      end)
    end)

    describe('boolean()', function()
      it('should accept booleans', function()
        assert.are.equal(true, g.boolean():parse(true))
        assert.are.equal(false, g.boolean():parse(false))
      end)

      it('should reject non-booleans', function()
        assert.has_error(function() g.boolean():parse(1) end)
        assert.has_error(function() g.boolean():parse 'true' end)
        assert.has_error(function() g.boolean():parse(nil) end)
      end)
    end)

    describe('nil_()', function()
      it('should accept nil', function() assert.is_nil(g.nil_():parse(nil)) end)

      it('should reject non-nil', function()
        assert.has_error(function() g.nil_():parse(0) end)
        assert.has_error(function() g.nil_():parse '' end)
        assert.has_error(function() g.nil_():parse(false) end)
      end)
    end)

    describe('any()', function()
      it('should accept anything', function()
        assert.are.equal('hello', g.any():parse 'hello')
        assert.are.equal(42, g.any():parse(42))
        assert.is_nil(g.any():parse(nil))
        local t = { a = 1 }
        assert.are.equal(t, g.any():parse(t))
      end)
    end)

    describe('table()', function()
      it('should accept tables', function()
        local t = { 1, 2, 3 }
        assert.are.equal(t, g.table():parse(t))
        assert.are.same({}, g.table():parse {})
      end)

      it('should reject non-tables', function()
        assert.has_error(function() g.table():parse 'table' end)
        assert.has_error(function() g.table():parse(nil) end)
      end)
    end)

    describe('func()', function()
      it('should accept functions', function()
        local f = function() end
        assert.are.equal(f, g.func():parse(f))
      end)

      it('should reject non-functions', function()
        assert.has_error(function() g.func():parse 'function' end)
        assert.has_error(function() g.func():parse {} end)
      end)
    end)

    describe('userdata()', function()
      it('should accept userdata', function()
        local handle = vim.uv.new_timer()
        assert.are.equal(handle, g.userdata():parse(handle))
        handle:close()
      end)

      it('should reject non-userdata', function()
        assert.has_error(function() g.userdata():parse 'userdata' end)
        assert.has_error(function() g.userdata():parse {} end)
      end)
    end)

    describe('thread()', function()
      it('should accept coroutines', function()
        local co = coroutine.create(function() end)
        assert.are.equal(co, g.thread():parse(co))
      end)

      it('should reject non-threads', function()
        assert.has_error(function() g.thread():parse 'thread' end)
        assert.has_error(function() g.thread():parse {} end)
      end)
    end)
  end)

  describe('literal()', function()
    it('should match exact values', function()
      assert.are.equal('foo', g.literal('foo'):parse 'foo')
      assert.are.equal(42, g.literal(42):parse(42))
      assert.are.equal(true, g.literal(true):parse(true))
    end)

    it('should accept multiple literal options', function()
      local status = g.literal('active', 'inactive', 'pending')
      assert.are.equal('active', status:parse 'active')
      assert.are.equal('inactive', status:parse 'inactive')
      assert.are.equal('pending', status:parse 'pending')
    end)

    it('should reject non-matching values', function()
      assert.has_error(function() g.literal('foo'):parse 'bar' end)
      assert.has_error(function() g.literal(1, 2, 3):parse(4) end)
    end)
  end)

  describe('pattern()', function()
    it('should match Lua patterns', function()
      assert.are.equal('hello', g.pattern('^%a+$'):parse 'hello')
      assert.are.equal('123', g.pattern('^%d+$'):parse '123')
    end)

    it('should reject non-matching strings', function()
      assert.has_error(function() g.pattern('^%d+$'):parse 'abc' end)
      assert.has_error(function() g.pattern('^hello$'):parse 'hello world' end)
    end)

    it('should reject non-strings', function()
      assert.has_error(function() g.pattern('^%d+$'):parse(123) end)
    end)
  end)

  describe('object()', function()
    it('should validate object shape', function()
      local User = g.object {
        name = g.string(),
        age = g.number(),
      }
      local result = User:parse { name = 'Alice', age = 30 }
      assert.are.equal('Alice', result.name)
      assert.are.equal(30, result.age)
    end)

    it('should allow extra keys by default (passthrough)', function()
      local User = g.object {
        name = g.string(),
      }
      local result = User:parse { name = 'Alice', extra = 'value' }
      assert.are.equal('Alice', result.name)
      assert.are.equal('value', result.extra)
    end)

    it('should reject extra keys in strict mode', function()
      local User = g.object({
        name = g.string(),
      }, { strict = true })
      assert.has_error(function() User:parse { name = 'Alice', extra = 'value' } end)
    end)

    it('should reject non-tables', function()
      local User = g.object { name = g.string() }
      assert.has_error(function() User:parse 'not a table' end)
      assert.has_error(function() User:parse(nil) end)
    end)

    it('should report nested errors', function()
      local User = g.object {
        name = g.string(),
        age = g.number(),
      }
      local ok, err = pcall(function() User:parse { name = 123, age = 'thirty' } end)
      assert.is_false(ok)
      assert.matches('name', tostring(err))
      assert.matches('age', tostring(err))
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
      assert.are.equal('NYC', result.address.city)
    end)

    it('should reject missing required fields', function()
      local User = g.object { name = g.string() }
      assert.has_error(function() User:parse {} end)
      assert.has_error(function() User:parse { name = nil } end)
    end)
  end)

  describe('record()', function()
    it('should validate uniform key/value types', function()
      local StringToNumber = g.record(g.string(), g.number())
      local result = StringToNumber:parse { a = 1, b = 2, c = 3 }
      assert.are.equal(1, result.a)
      assert.are.equal(2, result.b)
      assert.are.equal(3, result.c)
    end)

    it('should reject invalid values', function()
      local StringToNumber = g.record(g.string(), g.number())
      assert.has_error(function() StringToNumber:parse { a = 'not a number' } end)
    end)

    it('should report the key and its problem when a key fails', function()
      local StringToNumber = g.record(g.string(), g.number())
      local result = StringToNumber:try_parse { [1] = 10 }
      assert.is_false(result.ok)
      local msg = g.ParseError.new(result.actual, result.problems):format(false)
      assert.is_truthy(msg:find('[key "1"]', 1, true), msg)
      assert.is_truthy(msg:find('Expected string', 1, true), msg)
    end)
  end)

  describe('array()', function()
    it('should validate array items', function()
      local Numbers = g.array(g.number())
      local result = Numbers:parse { 1, 2, 3 }
      assert.are.same({ 1, 2, 3 }, result)
    end)

    it('should work with guard:array() method', function()
      local Strings = g.string():array()
      local result = Strings:parse { 'a', 'b', 'c' }
      assert.are.same({ 'a', 'b', 'c' }, result)
    end)

    it('should reject invalid items', function()
      local Numbers = g.array(g.number())
      assert.has_error(function() Numbers:parse { 1, 'two', 3 } end)
    end)

    it('should handle empty arrays', function()
      local Numbers = g.array(g.number())
      assert.are.same({}, Numbers:parse {})
    end)

    it('should report index in error', function()
      local Numbers = g.array(g.number())
      local ok, err = pcall(function() Numbers:parse { 1, 2, 'three' } end)
      assert.is_false(ok)
      assert.matches('%[3%]', tostring(err))
    end)

    it('should coerce nil to empty array with from_nil option', function()
      local Numbers = g.number():array { from_nil = true }
      assert.are.same({}, Numbers:parse(nil))
    end)
  end)

  describe('array_nonempty()', function()
    it('should accept non-empty arrays', function()
      local Numbers = g.number():array_nonempty()
      assert.are.same({ 1 }, Numbers:parse { 1 })
      assert.are.same({ 1, 2, 3 }, Numbers:parse { 1, 2, 3 })
    end)

    it('should reject empty arrays', function()
      local Numbers = g.number():array_nonempty()
      assert.has_error(function() Numbers:parse {} end)
    end)
  end)

  describe('tuple()', function()
    it('should validate fixed-length tuples', function()
      local Point = g.tuple(g.number(), g.number())
      local result = Point:parse { 10, 20 }
      assert.are.equal(10, result[1])
      assert.are.equal(20, result[2])
    end)

    it('should validate mixed-type tuples', function()
      local Entry = g.tuple(g.string(), g.number(), g.boolean())
      local result = Entry:parse { 'key', 42, true }
      assert.are.equal('key', result[1])
      assert.are.equal(42, result[2])
      assert.are.equal(true, result[3])
    end)

    it('should reject wrong length', function()
      local Point = g.tuple(g.number(), g.number())
      assert.has_error(function() Point:parse { 1 } end)
      assert.has_error(function() Point:parse { 1, 2, 3 } end)
    end)

    it('should reject wrong types', function()
      local Point = g.tuple(g.number(), g.number())
      assert.has_error(function() Point:parse { 1, 'two' } end)
    end)
  end)

  describe('one_of()', function()
    it('should accept any matching guard', function()
      local StringOrNumber = g.one_of(g.string(), g.number())
      assert.are.equal('hello', StringOrNumber:parse 'hello')
      assert.are.equal(42, StringOrNumber:parse(42))
    end)

    it('should reject if none match', function()
      local StringOrNumber = g.one_of(g.string(), g.number())
      assert.has_error(function() StringOrNumber:parse(true) end)
      assert.has_error(function() StringOrNumber:parse {} end)
    end)

    it('should work with or_() method', function()
      local StringOrNumber = g.string():or_(g.number())
      assert.are.equal('hello', StringOrNumber:parse 'hello')
      assert.are.equal(42, StringOrNumber:parse(42))
    end)
  end)

  describe('all_of()', function()
    it('should require all guards to match', function()
      local HasName = g.object { name = g.string() }
      local HasAge = g.object { age = g.number() }
      local Person = g.all_of(HasName, HasAge)

      local result = Person:parse { name = 'Alice', age = 30 }
      assert.are.equal('Alice', result.name)
      assert.are.equal(30, result.age)
    end)

    it('should reject if any guard fails', function()
      local HasName = g.object { name = g.string() }
      local HasAge = g.object { age = g.number() }
      local Person = g.all_of(HasName, HasAge)

      assert.has_error(function()
        Person:parse { name = 'Alice' } -- missing age
      end)
    end)

    it('should work with and_() method', function()
      local HasName = g.object { name = g.string() }
      local HasAge = g.object { age = g.number() }
      local Person = HasName:and_(HasAge)

      local result = Person:parse { name = 'Alice', age = 30 }
      assert.are.equal('Alice', result.name)
    end)
  end)

  describe('instance_of()', function()
    it('should accept values with the metatable', function()
      local Point = {}
      local point = setmetatable({ x = 1, y = 2 }, Point)
      assert.are.equal(point, g.instance_of(Point, 'Point'):parse(point))
    end)

    it('should reject tables with another metatable', function()
      local Point = {}
      assert.has_error(function() g.instance_of(Point, 'Point'):parse {} end)
      assert.has_error(function() g.instance_of(Point, 'Point'):parse(setmetatable({}, {})) end)
    end)

    it('should reject non-tables', function()
      assert.has_error(function() g.instance_of({}, 'Point'):parse 'Point' end)
    end)

    it('should name the metatable and the generic fallback in errors', function()
      local Point = {}
      local named = g.instance_of(Point, 'Point'):try_parse {}
      local named_msg = g.ParseError.new(named.actual, named.problems):format(false)
      assert.is_truthy(named_msg:find('Expected instance of Point', 1, true), named_msg)

      local unnamed = g.instance_of(Point):try_parse {}
      local unnamed_msg = g.ParseError.new(unnamed.actual, unnamed.problems):format(false)
      assert.is_truthy(
        unnamed_msg:find('Expected instance of specific metatable', 1, true),
        unnamed_msg
      )
    end)
  end)

  describe('optional()', function()
    it('should allow nil', function()
      local MaybeString = g.string():optional()
      assert.are.equal('hello', MaybeString:parse 'hello')
      assert.is_nil(MaybeString:parse(nil))
    end)

    it('should still reject wrong types', function()
      local MaybeString = g.string():optional()
      assert.has_error(function() MaybeString:parse(123) end)
    end)
  end)

  describe('map()', function()
    it('should transform the value', function()
      local Doubled = g.number():map(function(x) return g.ok(x * 2) end)
      assert.are.equal(84, Doubled:parse(42))
    end)

    it('should chain transformations', function()
      local Processed = g.string()
        :map(function(s) return g.ok(s:upper()) end)
        :map(function(s) return g.ok(s .. '!') end)
      assert.are.equal('HELLO!', Processed:parse 'hello')
    end)

    it('should allow returning errors', function()
      local Positive = g.number():map(function(x)
        if x <= 0 then return g.err(x, { { path = {}, message = 'Must be positive' } }) end
        return g.ok(x)
      end)
      assert.are.equal(42, Positive:parse(42))
      assert.has_error(function() Positive:parse(-1) end)
    end)
  end)

  describe('invariant()', function()
    it('should pass when predicate is true', function()
      local Positive = g.number():invariant(function(x) return x > 0 end, 'Must be positive')
      assert.are.equal(42, Positive:parse(42))
    end)

    it('should fail when predicate is false', function()
      local Positive = g.number():invariant(function(x) return x > 0 end, 'Must be positive')
      assert.has_error(function() Positive:parse(-1) end)
    end)
  end)

  describe('into_number()', function()
    it('should pass through numbers', function()
      assert.are.equal(42, g.into_number():parse(42))
      assert.are.equal(3.14, g.into_number():parse(3.14))
    end)

    it('should parse numeric strings', function()
      assert.are.equal(42, g.into_number():parse '42')
      assert.are.equal(3.14, g.into_number():parse '3.14')
      assert.are.equal(-100, g.into_number():parse '-100')
    end)

    it('should reject non-numeric strings', function()
      assert.has_error(function() g.into_number():parse 'hello' end)
      assert.has_error(function() g.into_number():parse '' end)
    end)

    it('should reject other types', function()
      assert.has_error(function() g.into_number():parse(true) end)
      assert.has_error(function() g.into_number():parse {} end)
    end)
  end)

  describe('into_string()', function()
    it(
      'should pass through strings',
      function() assert.are.equal('hello', g.into_string():parse 'hello') end
    )

    it('should convert numbers to strings', function()
      assert.are.equal('42', g.into_string():parse(42))
      assert.are.equal('3.14', g.into_string():parse(3.14))
    end)

    it('should convert booleans to strings', function()
      assert.are.equal('true', g.into_string():parse(true))
      assert.are.equal('false', g.into_string():parse(false))
    end)

    it('should reject values with no string form', function()
      assert.has_error(function() g.into_string():parse {} end)
      assert.has_error(function()
        g.into_string():parse(function() end)
      end)
    end)
  end)

  describe('into_boolean()', function()
    it('should pass through booleans', function()
      assert.are.equal(true, g.into_boolean():parse(true))
      assert.are.equal(false, g.into_boolean():parse(false))
    end)

    it('should parse truthy strings', function()
      assert.are.equal(true, g.into_boolean():parse 'true')
      assert.are.equal(true, g.into_boolean():parse 'TRUE')
      assert.are.equal(true, g.into_boolean():parse '1')
      assert.are.equal(true, g.into_boolean():parse 'yes')
    end)

    it('should parse falsy strings', function()
      assert.are.equal(false, g.into_boolean():parse 'false')
      assert.are.equal(false, g.into_boolean():parse 'FALSE')
      assert.are.equal(false, g.into_boolean():parse '0')
      assert.are.equal(false, g.into_boolean():parse 'no')
      assert.are.equal(false, g.into_boolean():parse '')
    end)

    it('should convert numbers to booleans', function()
      assert.are.equal(true, g.into_boolean():parse(1))
      assert.are.equal(true, g.into_boolean():parse(-1))
      assert.are.equal(false, g.into_boolean():parse(0))
    end)

    it('should reject strings that are not boolean words', function()
      assert.has_error(function() g.into_boolean():parse 'maybe' end)
    end)

    it('should reject values with no boolean form', function()
      assert.has_error(function() g.into_boolean():parse {} end)
      assert.has_error(function()
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
      assert.are.equal('test', result.name)
      assert.are.equal(42, result.value)
    end)

    it('should reject invalid JSON', function()
      local JsonObject = g.from_json(g.any())
      assert.has_error(function() JsonObject:parse 'not valid json' end)
    end)

    it('should validate parsed JSON against guard', function()
      local JsonNumber = g.from_json(g.number())
      assert.are.equal(42, JsonNumber:parse '42')
      assert.has_error(function() JsonNumber:parse '"not a number"' end)
    end)
  end)

  describe('into_json()', function()
    it('should serialize to JSON', function()
      local result = g.into_json():parse { name = 'test', value = 42 }
      -- Decode to verify (order may vary)
      local decoded = vim.json.decode(result)
      assert.are.equal('test', decoded.name)
      assert.are.equal(42, decoded.value)
    end)

    it('should serialize primitives', function()
      assert.are.equal('42', g.into_json():parse(42))
      assert.are.equal('"hello"', g.into_json():parse 'hello')
      assert.are.equal('true', g.into_json():parse(true))
    end)

    it('should reject values that JSON cannot serialize', function()
      assert.has_error(function()
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

      assert.are.equal(123, result.id) -- coerced from string
      assert.are.equal('alice', result.username)
      assert.are.same({ 'admin', 'user' }, result.roles)
      assert.are.equal('dark', result.settings.theme)
    end)

    it('should validate API response', function()
      local ApiResponse = g.object {
        status = g.literal('ok', 'error'),
        data = g.any():optional(),
        error = g.string():optional(),
      }

      local success = ApiResponse:parse { status = 'ok', data = { items = {} } }
      assert.are.equal('ok', success.status)

      local failure = ApiResponse:parse { status = 'error', error = 'Not found' }
      assert.are.equal('error', failure.status)
      assert.are.equal('Not found', failure.error)
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
      assert.are.equal(8080, result.port)
      assert.are.equal('localhost', result.host)

      local custom = Config:parse { port = '3000' }
      assert.are.equal(3000, custom.port)
      assert.are.equal('localhost', custom.host)
    end)
  end)

  describe('error messages', function()
    it('should include path for nested object errors', function()
      local User = g.object {
        profile = g.object {
          name = g.string(),
        },
      }
      local result = User:try_parse { profile = { name = 123 } }
      assert.is_false(result.ok)
      assert.is_not_nil(result.problems)
      -- Use ParseError to format with path
      local err = g.ParseError.new(result.actual, result.problems)
      local msg = err:format(false)
      -- Path should show .profile.name
      assert.matches('%.profile%.name', msg)
      assert.matches('Expected string', msg)
    end)

    it('should include index for array errors', function()
      local Numbers = g.array(g.number())
      local result = Numbers:try_parse { 1, 2, 'bad', 4 }
      assert.is_false(result.ok)
      assert.is_not_nil(result.problems)
      local err = g.ParseError.new(result.actual, result.problems)
      local msg = err:format(false)
      assert.matches('%[3%]', msg)
      assert.matches('Expected number', msg)
    end)

    it('should collect multiple errors', function()
      local User = g.object {
        name = g.string(),
        age = g.number(),
        email = g.string(),
      }
      local result = User:try_parse { name = 123, age = 'old', email = false }
      assert.is_false(result.ok)
      assert.is_not_nil(result.problems)
      local err = g.ParseError.new(result.actual, result.problems)
      local msg = err:format(false)
      -- Should report all 3 problems
      assert.matches('3 problems', msg)
      assert.matches('%.name', msg)
      assert.matches('%.age', msg)
      assert.matches('%.email', msg)
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
      local result = Schema:try_parse {
        level1 = {
          level2 = {
            level3 = {
              { value = 1 },
              { value = 'bad' },
            },
          },
        },
      }
      assert.is_false(result.ok)
      assert.is_not_nil(result.problems)
      local err = g.ParseError.new(result.actual, result.problems)
      local msg = err:format(false)
      -- Should show full path: .level1.level2.level3[2].value
      assert.matches('%.level1%.level2%.level3%[2%]%.value', msg)
    end)

    it('should show actual values in verbose mode', function()
      local guard = g.number()
      local result = guard:try_parse 'not a number'
      assert.is_false(result.ok)
      assert.is_not_nil(result.problems)
      local err = g.ParseError.new(result.actual, result.problems)
      local verbose_msg = err:format(true)
      assert.matches('got:', verbose_msg)
      assert.matches('not a number', verbose_msg)
    end)

    it('should fall back to tostring when JSON cannot encode the value', function()
      local value = function() end
      local problems = { { path = {}, message = 'Expected number', actual = value } }
      local msg = g.ParseError.new(value, problems):format(true)
      assert.is_truthy(msg:find('got:', 1, true), msg)
      assert.is_truthy(msg:find('function:', 1, true), msg)
    end)

    it('should format ParseError nicely', function()
      local User = g.object { name = g.string() }
      local result = User:try_parse { name = 123 }
      assert.is_false(result.ok)
      assert.is_not_nil(result.problems)
      local err = g.ParseError.new(result.actual, result.problems)
      local msg = tostring(err)
      -- Should have header
      assert.matches('Validation failed', msg)
      -- Should have numbered list
      assert.matches('1%.', msg)
      -- Should show path in backticks
      assert.matches('`%.name`', msg)
    end)

    it('should handle array of objects with multiple errors', function()
      local Users = g.array(g.object {
        name = g.string(),
        age = g.number(),
      })
      local result = Users:try_parse {
        { name = 'Alice', age = 30 },
        { name = 123, age = 'old' },
        { name = 'Charlie', age = 25 },
      }
      assert.is_false(result.ok)
      assert.is_not_nil(result.problems)
      local err = g.ParseError.new(result.actual, result.problems)
      local msg = err:format(false)
      -- Should report errors for item [2]
      assert.matches('%[2%]%.name', msg)
      assert.matches('%[2%]%.age', msg)
      -- Should be 2 problems
      assert.matches('2 problems', msg)
    end)

    it('should show pattern in pattern error', function()
      local guard = g.pattern '^%d%d%d%-%d%d%d%d$'
      local result = guard:try_parse 'invalid'
      assert.is_false(result.ok)
      assert.is_not_nil(result.problems)
      local err = g.ParseError.new(result.actual, result.problems)
      local msg = err:format(false)
      assert.matches('pattern', msg)
    end)

    it('should show expected literals in literal error', function()
      local guard = g.literal('red', 'green', 'blue')
      local result = guard:try_parse 'yellow'
      assert.is_false(result.ok)
      assert.is_not_nil(result.problems)
      local err = g.ParseError.new(result.actual, result.problems)
      local msg = err:format(false)
      assert.matches('red', msg)
      assert.matches('green', msg)
      assert.matches('blue', msg)
    end)
  end)

  describe('try_parse()', function()
    it('should return ok result on success', function()
      local result = g.string():try_parse 'hello'
      assert.is_true(result.ok)
      assert.are.equal('hello', result.value)
    end)

    it('should return error result on failure', function()
      local result = g.string():try_parse(123)
      assert.is_false(result.ok)
      assert.is_not_nil(result.problems)
      assert.are.equal(1, #result.problems)
    end)
  end)

  describe('is() vs matches()', function()
    it('is() returns false for coerced values', function()
      -- into_number coerces '42' to 42, so is() should be false
      assert.is_false(g.into_number():is '42')
      -- but for actual numbers, is() should be true
      assert.is_true(g.into_number():is(42))
    end)

    it('matches() returns true for coercible values', function()
      assert.is_true(g.into_number():matches '42')
      assert.is_true(g.into_number():matches(42))
    end)

    it('is() is stricter than matches()', function()
      local guard = g.into_string()
      -- 42 can be coerced to '42'
      assert.is_true(guard:matches(42))
      -- but 42 is not already a string
      assert.is_false(guard:is(42))
      -- 'hello' is already a string
      assert.is_true(guard:is 'hello')
    end)
  end)

  describe('LuaCATS generation', function()
    describe('to_luacats()', function()
      it('should generate alias for primitives', function()
        assert.are.equal('---@alias MyString string', g.string():to_luacats 'MyString')
        assert.are.equal('---@alias MyNumber number', g.number():to_luacats 'MyNumber')
        assert.are.equal('---@alias MyBool boolean', g.boolean():to_luacats 'MyBool')
        assert.are.equal('---@alias MyInt integer', g.integer():to_luacats 'MyInt')
      end)

      it('should generate union for literals', function()
        local status = g.literal('active', 'inactive', 'pending')
        local result = status:to_luacats 'Status'
        assert.matches("'active'", result)
        assert.matches("'inactive'", result)
        assert.matches("'pending'", result)
        assert.matches('|', result)
      end)

      it('should generate class for objects', function()
        local User = g.object {
          name = g.string(),
          age = g.number(),
        }
        local result = User:to_luacats 'User'
        assert.matches('---@class User', result)
        assert.matches('---@field name string', result)
        assert.matches('---@field age number', result)
      end)

      it('should mark optional fields with ?', function()
        local User = g.object {
          name = g.string(),
          nickname = g.string():optional(),
        }
        local result = User:to_luacats 'User'
        assert.matches('---@field name string', result)
        assert.matches('---@field nickname%? string', result)
        -- Ensure we don't have double ? (the old bug)
        assert.is_nil(result:match 'string%?')
      end)

      it('should generate array types', function()
        local Numbers = g.array(g.number())
        assert.are.equal('---@alias Numbers number[]', Numbers:to_luacats 'Numbers')
      end)

      it('should generate nested class for nested objects', function()
        local User = g.object {
          profile = g.object {
            bio = g.string(),
          },
        }
        local result = User:to_luacats 'User'
        -- Should have both classes
        assert.matches('---@class User', result)
        assert.matches('---@class User_profile', result)
        assert.matches('---@field bio string', result)
      end)

      it('should generate record types', function()
        local StringMap = g.record(g.string(), g.number())
        local result = StringMap:to_luacats 'StringMap'
        assert.matches('table<string, number>', result)
      end)

      it('should generate union for one_of', function()
        local StringOrNumber = g.one_of(g.string(), g.number())
        local result = StringOrNumber:to_luacats 'StringOrNumber'
        assert.matches('string|number', result)
      end)

      it('should generate tuple types', function()
        local Point = g.tuple(g.number(), g.number())
        local result = Point:to_luacats 'Point'
        assert.matches('%[number, number%]', result)
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
        assert.matches('---@class ApiResponse', result)
        assert.matches("'ok'|'error'", result)
        assert.matches('---@field items', result)
      end)
    end)

    describe('infer_type()', function()
      it('should return type string for primitives', function()
        assert.are.equal('string', g.string():infer_type())
        assert.are.equal('number', g.number():infer_type())
        assert.are.equal('boolean', g.boolean():infer_type())
        assert.are.equal('integer', g.integer():infer_type())
        assert.are.equal('table', g.table():infer_type())
        assert.are.equal('function', g.func():infer_type())
        assert.are.equal('userdata', g.userdata():infer_type())
        assert.are.equal('thread', g.thread():infer_type())
        assert.are.equal('any', g.any():infer_type())
        assert.are.equal('nil', g.nil_():infer_type())
      end)

      it('should return array notation for arrays', function()
        assert.are.equal('string[]', g.string():array():infer_type())
        assert.are.equal('number[]', g.number():array():infer_type())
      end)

      it(
        'should return optional notation',
        function() assert.are.equal('string?', g.string():optional():infer_type()) end
      )

      it('should preserve type through invariant', function()
        local Positive = g.number():invariant(function(x) return x > 0 end, 'Must be positive')
        assert.are.equal('number', Positive:infer_type())
      end)

      it('should preserve the inner type through map', function()
        local Doubled = g.number():map(function(x) return g.ok(x * 2) end)
        assert.are.equal('number', Doubled:infer_type())
      end)

      it('should use the first guard for all_of', function()
        assert.are.equal('string', g.all_of(g.string(), g.pattern '^x'):infer_type())
        assert.are.equal('any', g.all_of():infer_type())
      end)

      it('should name instance_of types', function()
        local Point = {}
        assert.are.equal('Point', g.instance_of(Point, 'Point'):infer_type())
        assert.are.equal('specific metatable', g.instance_of(Point):infer_type())
      end)

      it(
        'should infer literal unions and fall back to any for other values',
        function() assert.are.equal('1|true|any', g.literal(1, true, {}):infer_type()) end
      )

      it('should fall back to any when a schema has no inferable metadata', function()
        local function opaque(schema)
          return g.Guard.new(schema, function(x) return g.ok(x) end)
        end
        assert.are.equal('any?', opaque({ type = 'optional' }):infer_type())
        assert.are.equal('any[]', opaque({ type = 'array' }):infer_type())
        assert.are.equal('any', opaque({ type = 'map' }):infer_type())
        assert.are.equal('any', opaque({ type = 'custom' }):infer_type())
        assert.are.equal('any', opaque({ type = 'unknown' }):infer_type())
      end)
    end)

    describe('_schema metadata', function()
      it('should be present on primitives', function()
        assert.are.equal('string', g.string()._schema.type)
        assert.are.equal('number', g.number()._schema.type)
        assert.are.equal('boolean', g.boolean()._schema.type)
      end)

      it('should be present on composites', function()
        local obj = g.object { name = g.string() }
        assert.are.equal('object', obj._schema.type)
        assert.is_not_nil(obj._schema.fields)
        assert.is_not_nil(obj._schema.fields.name)
      end)

      it('should be present on arrays', function()
        local arr = g.string():array()
        assert.are.equal('array', arr._schema.type)
        assert.is_not_nil(arr._schema.item_guard)
      end)

      it('should store literal values', function()
        local lit = g.literal('a', 'b', 'c')
        assert.are.equal('literal', lit._schema.type)
        assert.are.same({ 'a', 'b', 'c' }, lit._schema.values)
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
local function cli(argv)
  local cmd = { 'nvim', '--clean' }
  -- Under `busted --coverage`, instrument the child so its CLI lines count.
  if package.loaded['luacov.runner'] then
    cmd[#cmd + 1] = '--cmd'
    cmd[#cmd + 1] = 'lua require("luacov")'
    -- The child runs too few instrumented lines to reach luacov's tick
    -- interval, and Neovim does not exit through Lua's os.exit, so save at the
    -- event Neovim does emit.
    cmd[#cmd + 1] = '--cmd'
    cmd[#cmd + 1] = 'autocmd VimLeavePre * lua require("luacov.runner").save_stats()'
  end
  cmd[#cmd + 1] = '-l'
  -- Keep this relative. luacov keys stats by the path string a chunk was loaded
  -- from, so the parent's relative `lua/guard.lua` and the child's absolute path
  -- would appear as two files in the coverage report.
  cmd[#cmd + 1] = 'lua/guard.lua'
  for _, arg in ipairs(argv) do
    cmd[#cmd + 1] = arg
  end
  return vim.system(cmd, { text = true }):wait()
end

--- @param argv string[]
--- @return vim.SystemCompleted
local function run_ok(argv)
  local proc = cli(argv)
  assert.are.equal(0, proc.code, proc.stderr)
  return proc
end

--- @param argv string[]
--- @param pattern string
local function run_fail(argv, pattern)
  local proc = cli(argv)
  assert.are.equal(1, proc.code, proc.stdout)
  local stderr = proc.stderr or ''
  assert.is_truthy(
    stderr:find(pattern, 1, true),
    ('expected %q in error %q'):format(pattern, stderr)
  )
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
        assert.is_truthy(stdout:find('Usage: guard', 1, true), stdout)
        assert.is_truthy(stdout:find('--module', 1, true), stdout)
      end
    end)

    it('prints both versions', function()
      for _, flag in ipairs { '--version', '-V' } do
        local proc = run_ok { flag }
        local stdout = proc.stdout or ''
        assert.is_truthy(stdout:match '^guard %d+%.%d+%.%d+ %(Neovim %d+%.%d+%.%d+', stdout)
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
      assert.is_truthy(generated:find('---@alias schemas.Answer integer', 1, true), generated)
    end)
  end)

  describe('generation', function()
    it('writes annotations next to the schema file', function()
      local root = fixture { ['lua/schemas.lua'] = SCHEMA }
      local src = root .. '/lua/schemas.lua'
      local proc = run_ok { src }

      assert.is_truthy(
        (proc.stdout or ''):find('Generated: ' .. types_path(src) .. ' (2 types)', 1, true),
        proc.stdout
      )

      local generated = slurp(types_path(src))
      assert.is_truthy(generated:find('---@class schemas.api.User', 1, true), generated)
      assert.is_truthy(generated:find('---@field name string', 1, true), generated)
      assert.is_truthy(generated:find('---@field age? number', 1, true), generated)
      assert.is_truthy(generated:find("---@alias schemas.Status 'ok'|'error'", 1, true), generated)
    end)

    it('records the regeneration command in the header', function()
      local root = fixture { ['lua/schemas.lua'] = SCHEMA }
      local src = root .. '/lua/schemas.lua'
      run_ok { src }

      local generated = slurp(types_path(src))
      assert.is_truthy(generated:find('-- To regenerate, run: nvim -l ', 1, true), generated)
      assert.is_truthy(generated:find(src, 1, true), generated)
    end)

    it('records a custom module in the regeneration command', function()
      local root = fixture {
        ['lua/schemas.lua'] = "local g = require 'custom.guard'\nreturn { Answer = g.integer() }\n",
      }
      local src = root .. '/lua/schemas.lua'
      run_ok { '--module', 'custom.guard', src }

      local generated = slurp(types_path(src))
      assert.is_truthy(generated:find('--module custom.guard', 1, true), generated)
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
      assert.is_truthy(generated:find('---@alias schemas.A string', 1, true), generated)
      assert.is_truthy(generated:find('---@alias schemas.B number', 1, true), generated)
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
      local _, classes = generated:gsub('%-%-%-@class ', '')
      local _, aliases = generated:gsub('%-%-%-@alias ', '')
      assert.are.equal(1, classes)
      assert.are.equal(1, aliases)
    end)

    it('expands a glob and skips existing .types.lua files', function()
      local root = fixture {
        ['lua/a.lua'] = "local g = require 'guard'\nreturn { A = g.string() }\n",
        ['lua/b.lua'] = "local g = require 'guard'\nreturn { B = g.number() }\n",
        ['lua/c.types.lua'] = '-- sentinel\n',
      }
      run_ok { root .. '/lua/*.lua' }

      assert.is_truthy(
        slurp(types_path(root .. '/lua/a.lua')):find('---@alias a.A string', 1, true)
      )
      assert.is_truthy(
        slurp(types_path(root .. '/lua/b.lua')):find('---@alias b.B number', 1, true)
      )
      assert.are.equal('-- sentinel\n', slurp(root .. '/lua/c.types.lua'))
    end)

    it('skips a file that exports no table', function()
      local root = fixture { ['lua/plain.lua'] = 'return 1\n' }
      local proc = run_ok { root .. '/lua/plain.lua' }
      assert.is_truthy((proc.stdout or ''):find('no table exported', 1, true), proc.stdout)
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
