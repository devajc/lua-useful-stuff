--------------------------------------------------------------------------------
-- 0320-timestamp.lua: tests for timestamp-related utilities
-- This file is a part of lua-nucleo library
-- Copyright (c) lua-nucleo authors (see file `COPYRIGHT` for the license)
--------------------------------------------------------------------------------

local make_suite = assert(loadfile('test/test-lib/init/strict.lua'))(...)

--------------------------------------------------------------------------------

local get_day_timestamp,
      get_yesterday_timestamp,
      get_tomorrow_timestamp,
      get_quarter_timestamp,
      get_minute_timestamp,
      get_decasecond_timestamp,
      exports
      = import 'lua-nucleo/timestamp.lua'
      {
        'get_day_timestamp',
        'get_yesterday_timestamp',
        'get_tomorrow_timestamp',
        'get_quarter_timestamp',
        'get_minute_timestamp',
        'get_decasecond_timestamp'
      }

local ensure_equals,
      ensure
      = import 'lua-nucleo/ensure.lua'
      {
        'ensure_equals',
        'ensure'
      }

--------------------------------------------------------------------------------

local test = make_suite("timestamp", exports)

--------------------------------------------------------------------------------

local os_time, os_date, math_random = os.time, os.date, math.random
local current_time = os_time()

test:test_for 'get_day_timestamp' (function()
  local day_time_stamp
  -- check all daytimestamps timestamps are equal to themselves
  for i = (current_time - 365*24*60*60), (current_time + 365*24*60*60), 60*60 do
    day_time_stamp = get_day_timestamp(i);
    ensure_equals("day timestamps equals", day_time_stamp,  get_day_timestamp(day_time_stamp))
  end
end)

test:test_for 'get_yesterday_timestamp' (function()
  local yesterday_timestamp
  local time_table

  for i = (current_time - 365*24*60*60), (current_time + 365*24*60*60), 60*60 do
    yesterday_timestamp = get_yesterday_timestamp(i)

    time_table = os_date("*t", i)
    time_table.isdst = nil
    time_table.day = time_table.day - 1

    ensure_equals(
        "previous day timestamps equals",
        yesterday_timestamp,
        get_day_timestamp(os.time(time_table))
      )
  end
end)

test:test_for 'get_tomorrow_timestamp' (function()
  local tomorrow_timestamp
  local time_table

  for i = (current_time - 365*24*60*60), (current_time + 365*24*60*60), 60*60 do
    tomorrow_timestamp = get_tomorrow_timestamp(i)

    time_table = os_date("*t", i)
    time_table.isdst = nil
    time_table.day = time_table.day + 1

    ensure_equals(
        "next day timestamps equals",
        tomorrow_timestamp,
        get_day_timestamp(os.time(time_table))
      )
  end
end)

test:test_for 'get_quarter_timestamp' (function()
  local quarter_time_stamp
  for i = current_time, (current_time + 365*24*60*60), 73 do
  -- 73 seconds in step to speed up test and get 365/73 = 5 round days
    quarter_time_stamp = get_quarter_timestamp(i)
    ensure_equals("quarter timestamps equals", quarter_time_stamp,  get_quarter_timestamp(quarter_time_stamp))
    if (i - current_time) % (24*60*60) == 0 then
      print("Day", ( (i - current_time) / (24*60*60) ) .. "/365", "OK")
    end
  end
end)

test 'get_quarter_timestamp_simple' (function()
  local quarter = get_quarter_timestamp(current_time)
  ensure_equals(
      "quarter timestamps +15 minutes",
      get_quarter_timestamp(current_time + 15 * 60) - quarter,
      15 * 60
    )
  ensure_equals(
      "quarter timestamps +30 minutes",
      get_quarter_timestamp(current_time + 30 * 60) - quarter,
      30 * 60
    )
  ensure_equals(
      "quarter timestamps +45 minutes",
      get_quarter_timestamp(current_time + 45 * 60) - quarter,
      45 * 60
    )
  ensure_equals(
      "quarter timestamps +60 minutes",
      get_quarter_timestamp(current_time + 60 * 60) - quarter,
      60 * 60
    )
end)

test:test_for 'get_minute_timestamp' (function()
  local minute_time_stamp
  for i = current_time, (current_time + 24*60*60), 1 do
    minute_time_stamp = get_minute_timestamp(i)
    ensure_equals("minute timestamps equals", minute_time_stamp,  get_minute_timestamp(minute_time_stamp))
    if (i - current_time) % (6*60*60) == 0 then
      print("Hour", ( (i - current_time) / (60*60) ) .. "/24", "OK")
    end
  end
end)

test:test_for 'get_decasecond_timestamp' (function()
  local decasecond_time_stamp
  for i = current_time, (current_time + 60*60), 1 do
    decasecond_time_stamp = get_decasecond_timestamp(i)
    ensure_equals(
        "ten seconds timestamps equals",
        decasecond_time_stamp,
        get_decasecond_timestamp(decasecond_time_stamp)
      )
  end

  ensure(
      "0 <= current_time - decasecond_timestamp < 10 sec",
      current_time - get_decasecond_timestamp(current_time) >= 0
        and current_time - get_decasecond_timestamp(current_time) < 10
    )

  local t = os_date("*t", current_time)
  t.sec = 9
  local time = os_time(t)
  decasecond_time_stamp = get_decasecond_timestamp(time)

  ensure_equals(
      "get_ten_seconds_timestamp for 9 sec is 0",
      time,
      decasecond_time_stamp + 9
    )

end)
