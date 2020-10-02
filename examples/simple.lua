#!/usr/bin/lua
local getch = require("lua-getch")
while true do
	print(getch.blocking())
end
