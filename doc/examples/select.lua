#!/usr/bin/env lua5.1
local getch = require("lua-getch")
-- This example demonstrates how to use select to wait for one or more file
-- descriptors to become ready.

print("Starting select example(wait for input without reading).")

-- enable raw mode, non-blocking terminal mode
getch.set_raw_mode(io.stdin)

local timeout = 5
print(("Print any key within the next %d seconds."):format(timeout))

-- do select with stdin checked for reading
local select_ret, stdin_read_ready = getch.select(timeout, false, io.stdin)
print("select returned:", select_ret, stdin_read_ready)

if stdin_read_ready then
	print("Character ready for reading!")
else
	print("Timeout reached!")
end

-- restore old terminal mode
getch.restore_mode()

print("bye!")
