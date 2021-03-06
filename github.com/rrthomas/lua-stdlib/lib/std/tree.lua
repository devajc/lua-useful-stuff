--- Tables as trees.
local base = require "std.base"
local ileaves, leaves = base.ileaves, base.leaves

local list = require "std.list"
local func = require "std.functional"


local metatable = {}
--- Make a table into a tree
-- @param t table
-- @return tree
local function new (t)
  return setmetatable (t or {}, metatable)
end

--- Tree <code>__index</code> metamethod.
-- @param tr tree
-- @param i non-table, or list of keys <code>{i<sub>1</sub> ...
-- i<sub>n</sub>}</code>
-- @return <code>tr[i]...[i<sub>n</sub>]</code> if i is a table, or
-- <code>tr[i]</code> otherwise
function metatable.__index (tr, i)
  -- FIXME: the following doesn't treat list keys correctly
  --        e.g. tr[{{1, 2}, {3, 4}}], maybe flatten first?
  if type (i) == "table" and #i > 0 then
    return list.foldl (func.op["[]"], tr, i)
  else
    return rawget (tr, i)
  end
end

--- Tree <code>__newindex</code> metamethod.
-- Sets <code>tr[i<sub>1</sub>]...[i<sub>n</sub>] = v</code> if i is a
-- table, or <code>tr[i] = v</code> otherwise
-- @param tr tree
-- @param i non-table, or list of keys <code>{i<sub>1</sub> ...
-- i<sub>n</sub>}</code>
-- @param v value
function metatable.__newindex (tr, i, v)
  if type (i) == "table" then
    for n = 1, #i - 1 do
      if getmetatable (tr[i[n]]) ~= metatable then
        rawset (tr, i[n], new ())
      end
      tr = tr[i[n]]
    end
    rawset (tr, i[#i], v)
  else
    rawset (tr, i, v)
  end
end

--- Make a deep copy of a tree, including any metatables
-- @param t table
-- @param nometa if non-nil don't copy metatables
-- @return copy of table
local function clone (t, nometa)
  local r = {}
  if not nometa then
    setmetatable (r, getmetatable (t))
  end
  local d = {[t] = r}
  local function copy (o, x)
    for i, v in pairs (x) do
      if type (v) == "table" then
        if not d[v] then
          d[v] = {}
          if not nometa then
            setmetatable (d[v], getmetatable (v))
          end
          o[i] = copy (d[v], v)
        else
          o[i] = d[v]
        end
      else
        o[i] = v
      end
    end
    return o
  end
  return copy (r, t)
end

---
-- @class function
-- @name tree_Iterator
-- @param n current node
-- @return type ("leaf", "branch" (pre-order) or "join" (post-order))
-- @return path to node ({i1...ik})
-- @return node
local function _nodes (it, tr)
  local p = {}
  local function visit (n)
    if type (n) == "table" then
      coroutine.yield ("branch", p, n)
      for i, v in it (n) do
        table.insert (p, i)
        visit (v)
        table.remove (p)
      end
      coroutine.yield ("join", p, n)
    else
      coroutine.yield ("leaf", p, n)
    end
  end
  return coroutine.wrap (visit), tr
end

--- Tree iterator.
-- @see tree_Iterator
-- @param tr tree to iterate over
-- @return iterator function
-- @return the tree, as above
local function nodes (tr)
  return _nodes (pairs, tr)
end

--- Tree iterator over numbered nodes, in order.
-- @see tree_Iterator
-- @param tr tree to iterate over
-- @return iterator function
-- @return the tree, as above
local function inodes (tr)
  return _nodes (ipairs, tr)
end

--- Deep-merge one tree into another. <code>u</code> is merged into
--- <code>t</code>.
-- @param t first tree
-- @param u second tree
-- @return first tree
local function merge (t, u)
  for ty, p, n in nodes (u) do
    if ty == "leaf" then
      t[p] = n
    end
  end
  return t
end

-- Public interface
local M = {
  clone   = clone,
  ileaves = ileaves,
  inodes  = inodes,
  leaves  = leaves,
  merge   = merge,
  new     = new,
  nodes   = nodes,
}

return M
