
-- This is a simple interface form making queries to postgres on top of
-- ngx_postgres
--
-- Add the following upstream to your http:
--
-- upstream database {
--   postgres_server  127.0.0.1 dbname=... user=... password=...;
-- }
--
-- Add the following location to your server:
--
-- location /query {
--   postgres_pass database;
--   postgres_query $echo_request_body;
-- }
--

parser = require "rds.parser"

import concat from table

local raw_query, logger

proxy_location = "/query"

set_logger = (l) -> logger = l
get_logger = -> logger

NULL = {}
raw = (val) -> {"raw", tostring(val)}

TRUE = raw"TRUE"
FALSE = raw"FALSE"

backends = {
  default: (_proxy=proxy_location) ->
    raw_query = (str) ->
      logger.query str if logger
      res, m = ngx.location.capture _proxy, {
        body: str
      }
      out = assert parser.parse res.body
      if resultset = out.resultset
        return resultset
      out

  raw: (fn) ->
    with raw_query
      raw_query = fn

  "resty.postgres": (opts) ->
    opts.host or= "127.0.0.1"
    opts.port or= 5432

    pg = require "lapis.resty.postgres"

    raw_query = (str) ->
      logger.query str if logger
      conn = pg\new!
      conn\set_keepalive 0, 100

      assert conn\connect opts
      assert conn\query str
}

set_backend = (name="default", ...) ->
  assert(backends[name]) ...

format_date = (time) ->
  os.date "!%Y-%m-%d %H:%M:%S", time

append_all = (t, ...) ->
  for i=1, select "#", ...
    t[#t + 1] = select i, ...

escape_identifier = (ident) ->
  ident = tostring ident
  '"' ..  (ident\gsub '"', '""') .. '"'

escape_literal = (val) ->
  switch type val
    when "number"
      return tostring val
    when "string"
      return "'#{(val\gsub "'", "''")}'"
    when "boolean"
      return val and "TRUE" or "FALSE"
    when "table"
      return "NULL" if val == NULL
      if val[1] == "raw" and val[2]
        return val[2]

  error "don't know how to escape value: #{val}"

-- replace ? with values
interpolate_query = (query, ...) ->
  values = {...}
  i = 0
  (query\gsub "%?", ->
    i += 1
    escape_literal values[i])

-- (col1, col2, col3) VALUES (val1, val2, val3)
encode_values = (t, buffer) ->
  have_buffer = buffer
  buffer or= {}

  tuples = [{k,v} for k,v in pairs t]
  cols = concat [escape_identifier pair[1] for pair in *tuples], ", "
  vals = concat [escape_literal pair[2] for pair in *tuples], ", "

  append_all buffer, "(", cols, ") VALUES (", vals, ")"
  concat buffer unless have_buffer

-- col1 = val1, col2 = val2, col3 = val3
encode_assigns = (t, buffer, join=", ") ->
  have_buffer = buffer
  buffer or= {}

  for k,v in pairs t
    append_all buffer, escape_identifier(k), " = ", escape_literal(v), join
  buffer[#buffer] = nil

  concat buffer unless have_buffer

raw_query = (...) ->
  set_backend "default"
  raw_query ...

query = (str, ...) ->
  if select("#", ...) > 0
    str = interpolate_query str, ...
  raw_query str

_select = (str, ...) ->
  query "SELECT " .. str, ...

_insert = (tbl, values, ...) ->
  if values._timestamp
    values._timestamp = nil
    time = format_date!

    values.created_at = time
    values.updated_at = time

  buff = {
    "INSERT INTO "
    escape_identifier(tbl)
    " "
  }
  encode_values values, buff

  returning = {...}
  if next returning
    append_all buff, " RETURNING "
    for i, r in ipairs returning
      append_all buff, escape_identifier r
      append_all buff, ", " if i != #returning

  raw_query concat buff

add_cond = (buffer, cond, ...) ->
  append_all buffer, " WHERE "
  switch type cond
    when "table"
      encode_assigns cond, buffer, " AND "
    when "string"
      append_all buffer, interpolate_query cond, ...

_update = (table, values, cond, ...) ->
  if values._timestamp
    values._timestamp = nil
    values.updated_at = format_date!

  buff = {
    "UPDATE "
    escape_identifier(table)
    " SET "
  }

  encode_assigns values, buff

  if cond
    add_cond buff, cond, ...

  raw_query concat buff

_delete = (table, cond, ...) ->
  buff = {
    "DELETE FROM "
    escape_identifier(table)
  }

  if cond
    add_cond buff, cond, ...

  raw_query concat buff

{
  :query, :raw, :NULL, :TRUE, :FALSE, :escape_literal, :escape_identifier
  :encode_values, :encode_assigns, :interpolate_query
  :set_logger, :get_logger

  :set_backend

  select: _select
  insert: _insert
  update: _update
  delete: _delete
}
