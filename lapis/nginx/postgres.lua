local parser = require("rds.parser")
local concat = table.concat
local raw_query, logger
local proxy_location = "/query"
local set_logger
set_logger = function(l)
  logger = l
end
local get_logger
get_logger = function()
  return logger
end
local NULL = { }
local raw
raw = function(val)
  return {
    "raw",
    tostring(val)
  }
end
local TRUE = raw("TRUE")
local FALSE = raw("FALSE")
local backends = {
  default = function(_proxy)
    if _proxy == nil then
      _proxy = proxy_location
    end
    raw_query = function(str)
      if logger then
        logger.query(str)
      end
      local res, m = ngx.location.capture(_proxy, {
        body = str
      })
      local out = assert(parser.parse(res.body))
      do
        local resultset = out.resultset
        if resultset then
          return resultset
        end
      end
      return out
    end
  end,
  raw = function(fn)
    do
      local _with_0 = raw_query
      raw_query = fn
      return _with_0
    end
  end,
  ["resty.postgres"] = function(opts)
    opts.host = opts.host or "127.0.0.1"
    opts.port = opts.port or 5432
    local pg = require("lapis.resty.postgres")
    raw_query = function(str)
      if logger then
        logger.query(str)
      end
      local conn = pg:new()
      conn:set_keepalive(0, 100)
      assert(conn:connect(opts))
      return assert(conn:query(str))
    end
  end
}
local set_backend
set_backend = function(name, ...)
  if name == nil then
    name = "default"
  end
  return assert(backends[name])(...)
end
local format_date
format_date = function(time)
  return os.date("!%Y-%m-%d %H:%M:%S", time)
end
local append_all
append_all = function(t, ...)
  for i = 1, select("#", ...) do
    t[#t + 1] = select(i, ...)
  end
end
local escape_identifier
escape_identifier = function(ident)
  ident = tostring(ident)
  return '"' .. (ident:gsub('"', '""')) .. '"'
end
local escape_literal
escape_literal = function(val)
  local _exp_0 = type(val)
  if "number" == _exp_0 then
    return tostring(val)
  elseif "string" == _exp_0 then
    return "'" .. tostring((val:gsub("'", "''"))) .. "'"
  elseif "boolean" == _exp_0 then
    return val and "TRUE" or "FALSE"
  elseif "table" == _exp_0 then
    if val == NULL then
      return "NULL"
    end
    if val[1] == "raw" and val[2] then
      return val[2]
    end
  end
  return error("don't know how to escape value: " .. tostring(val))
end
local interpolate_query
interpolate_query = function(query, ...)
  local values = {
    ...
  }
  local i = 0
  return (query:gsub("%?", function()
    i = i + 1
    return escape_literal(values[i])
  end))
end
local encode_values
encode_values = function(t, buffer)
  local have_buffer = buffer
  buffer = buffer or { }
  local tuples = (function()
    local _accum_0 = { }
    local _len_0 = 1
    for k, v in pairs(t) do
      _accum_0[_len_0] = {
        k,
        v
      }
      _len_0 = _len_0 + 1
    end
    return _accum_0
  end)()
  local cols = concat((function()
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = tuples
    for _index_0 = 1, #_list_0 do
      local pair = _list_0[_index_0]
      _accum_0[_len_0] = escape_identifier(pair[1])
      _len_0 = _len_0 + 1
    end
    return _accum_0
  end)(), ", ")
  local vals = concat((function()
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = tuples
    for _index_0 = 1, #_list_0 do
      local pair = _list_0[_index_0]
      _accum_0[_len_0] = escape_literal(pair[2])
      _len_0 = _len_0 + 1
    end
    return _accum_0
  end)(), ", ")
  append_all(buffer, "(", cols, ") VALUES (", vals, ")")
  if not (have_buffer) then
    return concat(buffer)
  end
end
local encode_assigns
encode_assigns = function(t, buffer, join)
  if join == nil then
    join = ", "
  end
  local have_buffer = buffer
  buffer = buffer or { }
  for k, v in pairs(t) do
    append_all(buffer, escape_identifier(k), " = ", escape_literal(v), join)
  end
  buffer[#buffer] = nil
  if not (have_buffer) then
    return concat(buffer)
  end
end
raw_query = function(...)
  set_backend("default")
  return raw_query(...)
end
local query
query = function(str, ...)
  if select("#", ...) > 0 then
    str = interpolate_query(str, ...)
  end
  return raw_query(str)
end
local _select
_select = function(str, ...)
  return query("SELECT " .. str, ...)
end
local _insert
_insert = function(tbl, values, ...)
  if values._timestamp then
    values._timestamp = nil
    local time = format_date()
    values.created_at = time
    values.updated_at = time
  end
  local buff = {
    "INSERT INTO ",
    escape_identifier(tbl),
    " "
  }
  encode_values(values, buff)
  local returning = {
    ...
  }
  if next(returning) then
    append_all(buff, " RETURNING ")
    for i, r in ipairs(returning) do
      append_all(buff, escape_identifier(r))
      if i ~= #returning then
        append_all(buff, ", ")
      end
    end
  end
  return raw_query(concat(buff))
end
local add_cond
add_cond = function(buffer, cond, ...)
  append_all(buffer, " WHERE ")
  local _exp_0 = type(cond)
  if "table" == _exp_0 then
    return encode_assigns(cond, buffer, " AND ")
  elseif "string" == _exp_0 then
    return append_all(buffer, interpolate_query(cond, ...))
  end
end
local _update
_update = function(table, values, cond, ...)
  if values._timestamp then
    values._timestamp = nil
    values.updated_at = format_date()
  end
  local buff = {
    "UPDATE ",
    escape_identifier(table),
    " SET "
  }
  encode_assigns(values, buff)
  if cond then
    add_cond(buff, cond, ...)
  end
  return raw_query(concat(buff))
end
local _delete
_delete = function(table, cond, ...)
  local buff = {
    "DELETE FROM ",
    escape_identifier(table)
  }
  if cond then
    add_cond(buff, cond, ...)
  end
  return raw_query(concat(buff))
end
return {
  query = query,
  raw = raw,
  NULL = NULL,
  TRUE = TRUE,
  FALSE = FALSE,
  escape_literal = escape_literal,
  escape_identifier = escape_identifier,
  encode_values = encode_values,
  encode_assigns = encode_assigns,
  interpolate_query = interpolate_query,
  set_logger = set_logger,
  get_logger = get_logger,
  set_backend = set_backend,
  select = _select,
  insert = _insert,
  update = _update,
  delete = _delete
}
