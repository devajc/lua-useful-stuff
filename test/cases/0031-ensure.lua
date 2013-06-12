--------------------------------------------------------------------------------
-- 0031-ensure.lua: tests for enhanced assertions
-- This file is a part of lua-nucleo library
-- Copyright (c) lua-nucleo authors (see file `COPYRIGHT` for the license)
--------------------------------------------------------------------------------

local make_suite = assert(loadfile('test/test-lib/init/strict.lua'))(...)

local ensure,
      ensure_equals,
      ensure_tequals,
      ensure_strequals,
      ensure_fails_with_substring,
      ensure_has_substring,
      ensure_is,
      ensure_exports
      = import 'lua-nucleo/ensure.lua'
      {
        'ensure',
        'ensure_equals',
        'ensure_tequals',
        'ensure_strequals',
        'ensure_fails_with_substring',
        'ensure_has_substring',
        'ensure_is'
      }

local ordered_pairs
      = import 'lua-nucleo/tdeepequals.lua'
      {
        'ordered_pairs'
      }

--------------------------------------------------------------------------------

local test = make_suite("ensure", ensure_exports)

--------------------------------------------------------------------------------

test:test_for "ensure_is" (function()
  local matrix =
  {
    ["number"] = 42;
    ["string"] = "lua-nucleo";
    ["table"] = { };
    ["function"] = function() end;
    ["userdata"] = io.stdout;
    ["thread"] = coroutine.create(function() end);
    ["boolean"] = true;
    ["nil"] = nil;
  }

  for typename, obj in ordered_pairs(matrix) do
    -- positive test
    ensure_is(
        "ensure_is broken for type `" .. typename .. "'",
        obj,
        typename
      )

    -- negative test
    for typename2, obj2 in ordered_pairs(matrix) do
      if typename2 ~= typename then
        ensure_fails_with_substring(
            "ensure_is() is false positive for type `" .. typename .. "'",
            function()
              ensure_is("msg", obj2, typename)
            end,
            "ensure_is failed: msg"
            .. ": actual type `" .. typename2
            .. "', expected type `" .. typename
            .. "'"
          )
      end
    end
  end
end)

--------------------------------------------------------------------------------

test:test_for "ensure_has_substring" (function()
  ensure_has_substring("positive test", "the answer is 42", "42")
  ensure_has_substring("positive test with pattern", "the answer is 42", "%d+")
  ensure_has_substring(
      "positive test with pattern 2",
      "the answer is %d",
      "the answer is %d"
    )

  ensure_strequals(
      "ensure_has_substring return test",
      ensure_has_substring("inner msg", "the answer is 42", '42'),
      "the answer is 42"
    )

  ensure_fails_with_substring(
      "negative test",
      function()
        ensure_has_substring("inner msg", "the answer is 42", 'not 42')
      end,
      "ensure_has_substring failed: inner msg:"
      .. " can't find expected substring `not 42'"
      .. " in string: `the answer is 42'"
    )
end)

--------------------------------------------------------------------------------

-- TODO: http://redmine.tech-zeli.in/issues/2413
test:UNTESTED "ensure"
test:UNTESTED "ensure_error"
test:UNTESTED "ensure_equals"
test:UNTESTED "ensure_tdeepequals"
test:UNTESTED "ensure_returns"
test:UNTESTED "ensure_error_with_substring"
test:UNTESTED "ensure_strequals"
test:UNTESTED "ensure_aposteriori_probability"
test:UNTESTED "ensure_fails_with_substring"
test:UNTESTED "ensure_tequals"
