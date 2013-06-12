--------------------------------------------------------------------------------
-- single-method-suite.lua: suite used for full suite tests
-- This file is a part of lua-nucleo library
-- Copyright (c) lua-nucleo authors (see file `COPYRIGHT` for the license)
--------------------------------------------------------------------------------

local make_suite = select(1, ...)
local test = make_suite("single-method-suite", { to_test = true })
test:factory "to_test" (function()
  local method = function() end;
  return
  {
    method = method;
  }
end)
test:method "method" (function() suite_tests_results = 1 end)
