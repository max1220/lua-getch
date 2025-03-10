#!/usr/bin/env lua5.1
local getch = require("lua-getch")
-- This example demonstrates how to read characters from stdin in a non-blocking
-- way by checking if new characters are available periodically.

print("Entering non-blocking example(checking once per second).")

-- set raw(non-linebuffered) mode, disable automatic echo of characters, enter non-blocking mode
getch.set_raw_mode(io.stdin, true)

local last_ch
local run = true
while run do
	-- go to beginning of line, write some info
	io.write("\r\027[2K"..os.date("(press q to quit) %H:%M:%S "))
	if last_ch then io.write("last ch=", last_ch, " ") end

	-- get characters if any, nil otherwise
	while true do
		local char = getch.get_char(io.stdin)
		if not char then break -- stdin has no char available
		elseif (char == 81) or (char == 113) then run = false -- q key
		elseif char then io.write("ch=", char, " "); last_ch = char
		end
	end
	io.flush()

	-- intentionally slowed down for this demo("your application loop here")
	os.execute("sleep 1")
end
print()

-- restore old terminal mode
getch.restore_mode()

print("bye!")
