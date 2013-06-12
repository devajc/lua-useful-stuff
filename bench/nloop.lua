local ipairs = ipairs

local t = {}
for i = 1, 55 do
  t[i] = i
end
t[51] = nil -- A hole

local bench = {}

-- Bench function does:
-- 1. Set all table elements to 0 until the first hole.
-- 2. Return hole position.

bench.loop_ipairs = function()
  local j
  for i, v in ipairs(t) do
    t[i] = 0
    j = i
  end
  return j + 1
end

bench.loop_for = function()
  local n = #t
  local j = n
  for i = 1, n do
    local v = t[i]
    if v == nil then
      j = i
      break
    end
    t[i] = 0
  end
  return j
end

bench.loop_while = function()
  local i = 1
  while t[i] ~= nil do
    t[i] = 0
    i = i + 1
  end
  return i
end
--[[
assert(bench.loop_ipairs() == 51)
assert(bench.loop_for() == 51)
assert(bench.loop_while() == 51)
--]]
return bench
