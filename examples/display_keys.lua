#!/usr/bin/env luajit
local getch = require("getch").blocking

local keys = {
  [27]= {
    [91] = {
      [65] = "up",
      [66] = "down",
      [67] = "right",
      [68] = "left"
    }
  }
}

function get_key(keys_table)
  local keys_table = keys_table or keys
  local ch = getch() -- Read a byte of stdinput
  local ret = keys_table[ch]
  if ret then
    if type(ret) == "string" then
      return ret
    elseif type(ret) == "table" then
      return get_key(ret)
    end
  else
    return nil, ch
  end
end


print("Press arrow keys or any character.")
while true do
  local key, char = get_key()
  if key then
    -- the read characters were found in keys table.
    print("Key:  ", key)
  else
    -- character(combination) was not in keys table, it must be a normal character
    print("Char: \"" .. string.char(char) .. "\"")
  end
end


