#!/usr/bin/lua
local getch = require("lua-getch")

-- map a sequence of integers to a string representing the resolved MBS for the arrow keys.
local key_table = {
	[10] = "enter",
	[27] = {
		[91] = {
			[65] = "up",
			[66] = "down",
			[67] = "right",
			[68] = "left"
		}
	}
}

local prompt = "Please select one of the menu items using the arrow keys and press enter:"
local menu = {
	"Hello World",
	"This is the Example menu",
	"You can also supply your own menu!",
	"Just pass the menu entries as arguments.",
	"The selected menu item is written to stdout,",
	"while all graphics are written to stderr.",
	"This makes useage in shell scripts easy.",
	"It also supports a --prompt= argument.",
	"quit",
}
if #arg > 0 then
	menu = {}
	for _,entry in ipairs(arg) do
		if entry:match("^%-%-prompt=(.+)$") then
			prompt = entry:match("^%-%-prompt=(.+)$")
		else
			table.insert(menu, tostring(entry))
		end
	end
end
local menu_i = 1
local selected

local function w(...)
	-- "graphical" terminal output to stderr
	io.stderr:write(...)
end

if #menu < 2 then
	w("Menu needs at least 2 items!")
	os.exit(1)
end

-- simple drawing routine using ANSI escape sequences
local function draw()
	-- reset sgr, clear screen, set cursor to 1,1
	w("\027[0m\027[2J\027[;H")
	w("\027[1m", prompt, "\027[0m\n\n")

	-- print menu items
	for k,v in ipairs(menu) do
		if k==menu_i then
			w("\027[31m [ ", tostring(v), " ]\027[0m\n")
		else
			w("   ",tostring(v),"  \n")
		end
	end
end

w("\027[?1049h") -- Enable alternative screen buffer
while true do
	draw()
	local key_code, key_resolved = getch.get_mbs(getch.blocking, key_table)
	if key_resolved == "up" then
		menu_i = math.max(menu_i-1, 1)
	elseif key_resolved == "down" then
		menu_i = math.min(menu_i+1, #menu)
	elseif key_resolved == "enter" then
		if menu[menu_i]:lower() == "quit" then
			os.exit(0)
		else
			selected = menu[menu_i]
			break
		end
	end
end
w("\027[?1049l") -- Disable alternative screen buffer

if selected then
	print(selected)
end
