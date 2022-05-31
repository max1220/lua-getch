#!/usr/bin/env lua5.1
local getch = require("lua-getch")
-- This example demonstrates a simple blocking getting single characters
-- from the terminal.

-- disable buffering through libc
io.stdin:setvbuf("no")

-- set raw(non-linebuffered) mode, disable automatic echo of characters
getch.set_raw_mode(io.stdin)

print("Press q to quit.")
while true do
	-- get a character, and abort on pressing q/Q key
	local char = getch.get_char(io.stdin)
	print("got character:",char)

	-- quit on q key
	if (char==("q"):byte()) or (char==("Q"):byte()) then
		break
	end
end

-- restore old terminal mode
getch.restore_mode()

-- enter line-buffered mode
io.stdin:setvbuf("line")

print("bye!")
