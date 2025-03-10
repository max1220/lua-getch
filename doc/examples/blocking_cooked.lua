#!/usr/bin/env lua5.1
local getch = require("lua-getch")
-- This example demonstrates how to read characters from stdin in a blocking way,
-- but respond to each byte immediately(using the "cooked" implementation which
-- automatically sets the raw mode before reading and leaves it afterwards).

print("Press q to quit.")
while true do
	-- get a character using the "cooked" mode
	local char = getch.get_char_cooked()
	print("got character:",char)

	-- quit on q key
	if (char == 81) or (char == 113) then break; end
end

print("bye!")
