#!/usr/bin/env lua5.1
local getch = require("lua-getch")

-- enable raw mode to read single characters immediately
getch.set_raw_mode(io.stdin)

-- call select with stdin as read_fd, so that when stdin becomes
-- ready for reading within the timeout it is returned.
-- (Returned files are in the same order as arguments, and only
-- files ready for reading or writing are returned).
print("Print any key within the next 5 seconds.")
local timeout = 5
local ok, stdin_ready = getch.select(timeout, io.stdin)
if stdin_ready then
	-- this should not block, because a character is ready now.
	local pressed_key = getch.get_char(io.stdin)
	print("Key pressed! Key was:", pressed_key)
elseif ok then
	print("Timeout! No key was pressed within the timeout!")
else
	print("An error occured!")
end

-- restore old terminal mode
getch.restore_mode()

print("bye!")
