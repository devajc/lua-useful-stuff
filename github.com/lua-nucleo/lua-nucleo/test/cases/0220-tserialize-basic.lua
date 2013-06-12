--------------------------------------------------------------------------------
-- 0220-tserialize-basic.lua: basic tests for tserialize
-- This file is a part of lua-nucleo library
-- Copyright (c) lua-nucleo authors (see file `COPYRIGHT` for the license)
--------------------------------------------------------------------------------

-- TODO: Employ test:tests_for idiom to check that all exports from
--       tdeepequals.lua are covered with tests.

local make_suite = assert(loadfile('test/test-lib/init/strict.lua'))(...)

local check_ok  = import 'test/test-lib/tserialize-test-utils.lua' { 'check_ok' }

---------------------------------------------------------------------------

local test = make_suite("syntetic basic tests")

---------------------------------------------------------------------------
test "nil param" (function() check_ok(nil) end)
test "complex nil param" (function() check_ok(nil, "a", nil, nil) end)
test "1" (function() check_ok() end)
test "2" (function() check_ok(true) end)
test "3" (function() check_ok(false) end)
test "4" (function() check_ok(42) end)
test "5" (function() check_ok(math.pi) end)
test "6" (function() check_ok("serialize") end)
test "7" (function() check_ok({ }) end)
test "8" (function() check_ok({ a = 1, 2 }) end)
test "9" (function() check_ok("") end)
test "10" (function() check_ok("Embedded\0Zero") end)
test "11" (function() check_ok(("longstring"):rep(1024000)) end)
test "12" (function() check_ok({ 1 }) end)
test "13" (function() check_ok({ a = 1 }) end)
test "14" (function() check_ok({ a = 1, 2, [42] = true, [math.pi] = 2 }) end)
test "15" (function() check_ok({ { } }) end)
test "16" (function() check_ok({ a = {}, b = { c = 7 } }) end)

test "17" (function()
  check_ok(nil, false, true, 42, "Embedded\0Zero", { { [{3}] = 54 } })
end)

test "18" (function() check_ok({ a = {}, b = { c = 7 } }, nil, { { } }, 42) end)
test "19" (function() check_ok({ ["1"] = "str", [1] = "num" }) end)
test "20" (function() check_ok({ [true] = true }) end)
test "21" (function() check_ok({ [true] = true, [false] = false, 1 }) end)

test "22" (function() check_ok(1/0, -1/0, 0/0) end)

test "23" (function() check_ok(1/3, math.pi) end)
test "24" (function() check_ok(
    0.0000000000000000000000000000000000000000000000000000000000000000000000123
  )
end)
