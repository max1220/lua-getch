#!/usr/bin/env lua5.1
local getch = require("lua-getch")
-- This example demonstrates how to read characters from stdin in a blocking way,
-- but respond to each byte immediately.

print("Entering blocking example(wait for input on stdin).")

-- set raw(non-linebuffered) mode, disable automatic echo of characters
getch.set_raw_mode(io.stdin)

print("Press q to quit.")
while true do
	-- get a character, and abort on pressing q/Q key
	local char = getch.get_char(io.stdin)
	print("got character:",char)

	-- quit on q key
	if (char == 81) or (char == 113) then break; end
end

-- restore old terminal mode
getch.restore_mode()

print("bye!")
