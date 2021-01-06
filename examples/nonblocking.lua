#!/usr/bin/lua
local getch = require("lua-getch")

local lastn = tonumber(arg[1]) or 10

local last_keys = {}
local last_time = os.date()
while true do
	-- try to get a character
	local c = getch.non_blocking()
	while c do
		table.insert(last_keys, tostring(c))
		last_time = os.date()
		if #last_keys == lastn then
			table.remove(last_keys, 1)
		end

		-- check if another character is immediatly available
		c = getch.non_blocking()
	end
	io.write("\027[2J") -- clear screen
	io.write("\027[;H") -- set cursor to origin
	print("Current time:", os.date())
	print("Last characters read:", table.concat(last_keys, ", "))
	print("Last characters pressed:", last_time)

	-- If you're just using terminal input, you could also just specify a timeout
	io.popen("sleep 0.1")
end
