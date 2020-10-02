#!/usr/bin/lua
local getch = require("lua-getch")

-- map a sequence of integers to a string representing the resolved MBS for the arrow keys.
local key_table = {
	[10] = "Enter",
	[27] = {
		[91] = {
			[65] = "up",
			[66] = "down",
			[67] = "right",
			[68] = "left"
		}
	}
}

local menu = {
	"Hello",
	"World",
	"foo",
	"bar",
	"buzz",
}
local menu_i = 1
local selected

local function draw_menu()
	-- simple drawing routine for a simple menu
	io:write("\027[0m") -- reset sgr
	io:write("\027[2j") -- clear screen
	io:write("\027[;H") -- set cursor to 1,1
	if selected then
		print("Please select one of the menu items using the arrow keys and enter:")
	else
		print("Last selected: ", menu[selected])
	end
	for k,v in ipairs(menu) do
		if k==menu_i then
			print("\027[31m" .. v .. "\027[0m")
		else
			print(v)
		end
	end
end

while true do
	local key_code, key_resolved = getch.get_mbs(getch.blocking, key_table)
	if key_resolved == "up" then
		menu_i = math.max(menu_i-1, 1)
	elseif key_resolved == "down" then
		menu_i = math.min(menu_i+1, #menu)
	elseif key_resolved == "enter" then
		selected = menu_i
	end
	draw_menu()
end
