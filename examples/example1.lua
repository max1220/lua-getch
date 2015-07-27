#!/usr/bin/lua
local getkey = require("getkey")
while true do
  print(string.byte(getkey.getkey()))
end
