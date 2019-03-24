#!/usr/bin/env luajit
local getch = require("getch")

local keys = {
  [getch.KEY_ENTER] = "enter",
  [getch.KEY_ESCAPE] = "escape",
  [getch.KEY_SPACE] = "space",
  [getch.KEY_LEFT] = "left",
  [getch.KEY_RIGHT] = "right",
  [getch.KEY_UP] = "up",
  [getch.KEY_DOWN] = "down"
}

function get_key()
  local ch = getch.blocking() -- Read a byte of stdinput
  return keys[ch] or nil, ch
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


