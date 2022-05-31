#!/usr/bin/lua
local getch = require("lua-getch")

while true do
	-- just print the terminal codes as integers
	print(getch.blocking())
end
