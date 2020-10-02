#!/usr/bin/lua
local getch = require("lua-getch")

-- map a sequence of integers to a string representing the resolved MBS for the arrow keys.
local key_table = {
	[27] = {
		[91] = {
			[65] = "up",
			[66] = "down",
			[67] = "right",
			[68] = "left"
		}
	}
}

while true do
	local key_code, key_resolved = getch.get_mbs(getch.blocking, key_table)
	if key_resolved then
		print("Arrow key pressed:", key_resolved)
	else
		print("Other key pressed:", key_code)
	end
end
