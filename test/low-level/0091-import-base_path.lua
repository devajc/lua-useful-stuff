--------------------------------------------------------------------------------
-- 0091-import-base_path.lua: tests for import module with base path set
-- This file is a part of lua-nucleo library
-- Copyright (c) lua-nucleo authors (see file `COPYRIGHT` for the license)
--------------------------------------------------------------------------------

-- Intentionally not using test suite to avoid circular dependency questions.

loadfile('lua-nucleo/import.lua')("test/data/") -- Import module should be loaded manually

local test_import = assert(assert(assert(loadfile("test/test-lib/import.lua"))())["test_import"])

test_import("")

print("------> Import-base_path tests suite PASSED")
