#!/usr/bin/env lua5.1
local getch = require("lua-getch")
local time = require("time")

-- disable buffering through libc
io.stdin:setvbuf("no")

-- set raw(non-linebuffered) mode, disable automatic echo of characters
getch.set_raw_mode(io.stdin)

-- set the non-blocking mode for stdin
getch.set_nonblocking(io.stdin, true)

print("Press q to quit.")
local last_char
while true do
	-- go to beginning of line, write some info
	io.write("\r"..os.date("(nonblocking) (press q to quit) %H:%M:%S"))

	-- get character if any, nil otherwise
	local char = getch.get_char(io.stdin)

	-- quit on q key
	if (char==("q"):byte()) or (char==("Q"):byte()) then
		break
	end

	-- write status of reading
	if char then
		last_char = char
		io.write(" Current char: "..char)
	elseif last_char then
		io.write(" Last char:    "..last_char)
		io.write(" (idle)")
	end
	io.write("      ")
	io.flush()

	-- intentionally slowed down ~10 characters/s
	time.sleep(0.1)
end
print()

-- restore old terminal mode
getch.restore_mode()

-- enter line-buffered mode
io.stdin:setvbuf("line")

-- set blocking mode
getch.set_nonblocking(io.stdin, false)

print("bye!")
