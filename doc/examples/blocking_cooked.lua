#!/usr/bin/env lua5.1
local getch = require("lua-getch")

print("Press q to quit.")
while true do
	-- get a character using the "cooked" mode
	-- that will automatically change the terminal mode,
	-- read the character from stdin, then restore the terminal.
	local char = getch.get_char_cooked()
	print("got character:",char)

	-- quit on q key
	if (char==("q"):byte()) or (char==("Q"):byte()) then
		break
	end
end

print("bye!")
