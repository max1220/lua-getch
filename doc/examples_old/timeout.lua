#!/usr/bin/lua
local getch = require("lua-getch")
local time = require("time")
local timeout = tonumber(arg[1]) or 1
while true do
	local start = time.monotonic()
	local c,err = getch.non_blocking(timeout)
	local dt = time.monotonic() - start
	print(("Waited %.3f seconds for %s"):format(dt,tostring(c and ("char: "..c) or ("error: "..err))))
end
