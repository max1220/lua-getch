#!/usr/bin/env lua5.1
local getch = require("lua-getch")

-- splits a string into a table, sep is a single-character pattern to match the seperator.
-- see http://lua-users.org/wiki/SplitJoin
local function split_by_pattern(str,sep)
   local ret={}
   local n=1
   for w in str:gmatch("([^"..sep.."]*)") do
      ret[n] = ret[n] or w -- only set once (so the blank after a string is ignored)
      if w=="" then
         n = n + 1
      end -- step forwards on a blank but not a string
   end
   return ret
end

-- string trim(remove leading/trailing whitespace)
local function trim(str)
   local from = str:match("^%s*()")
   return (from > #str) and "" or str:match(".*%S", from)
end

-- get the list of special keys
local function get_key_table()
	local key_table = {
		[10] = "enter",
		[9] = "tab",
		[127] = "backspace",
		[27] = {
			[27] = "escape",
			[91] = {
				[65] = "up",
				[66] = "down",
				[67] = "right",
				[68] = "left",
				[70] = "end",
				[72] = "pos1",
				[50] = {
					[126] = "insert"
				},
				[51] = {
					[126] = "delete"
				},
				[53] = {
					[126] = "pageup"
				},
				[54] = {
					[126] = "pagedown"
				}
			}
		}
	}

	-- add key combinations to key_table
	local exclude = {[3]=true, [9]=true, [10]=true, [13]=true, [17]=true, [19]=true, [26]=true}
	for i=1, 26 do
		if not exclude[i] then
			-- can't get these ctrl-codes via a terminal(e.g. ctrl-c)
			key_table[i] = "ctrl-"..string.char(i+96)
		end

		key_table[27][i+64] = "alt-"..string.char(i+96) -- e.g. alt-a
		key_table[27][i+96] = "alt-"..string.char(i+96) -- e.g. alt-shift-a
	end

	return key_table
end


-- ANSI terminal codes
-- luacheck: no unused
local fg_black = "\027[30m"
local fg_red = "\027[31m"
local fg_green = "\027[32m"
local fg_yellow = "\027[33m"
local fg_blue = "\027[34m"
local fg_magenta = "\027[35m"
local fg_cyan = "\027[36m"
local fg_white = "\027[37m"
local bg_black = "\027[40m"
local bg_red = "\027[41m"
local bg_green = "\027[42m"
local bg_yellow = "\027[43m"
local bg_blue = "\027[44m"
local bg_magenta = "\027[45m"
local bg_cyan = "\027[46m"
local bg_white = "\027[47m"
local reset_sgr = "\027[0m"
local clear_screen = "\027[2J"
local reset_cursor = "\027[;H"
local alternate_on = "\027[?1049h"
local alternate_off = "\027[?1049l"
local reset_all = reset_sgr .. clear_screen .. reset_cursor
local set_cursor_fmt = "\027[%d;%dH"
-- luacheck: unused


local function w(...)
	io.stderr:write(...)
end


local function primitive_repl()
	local repl_line = ""
	local cursor_x = 1
	local output_history = {}
	local input_history = {}
	local run = true
	local input_history_index
	local repl_env = {
		string = string, io = io, package = package, os = os, math = math,
		debug = debug,
		xpcall = xpcall, tostring = tostring, print = print, unpack = unpack,
		require = require, getfenv = getfenv, setmetatable = setmetatable,
		next = next, assert = assert, tonumber = tonumber, rawequal = rawequal,
		collectgarbage = collectgarbage, getmetatable = getmetatable,
		module = module, rawset = rawset, pcall = pcall, table = table,
		newproxy = newproxy, type = type, coroutine = coroutine, select = select,
		gcinfo = gcinfo, pairs = pairs, rawget = rawget, loadstring = loadstring,
		ipairs = ipairs, _VERSION = _VERSION, dofile = dofile, setfenv = setfenv,
		load = load, error = error, loadfile = loadfile,

		output_history = output_history,
		input_history = input_history,
	}
	local function output_str(str)
		local lines = split_by_pattern(str, "\n")
		for _,line in ipairs(lines) do
			table.insert(output_history, line)
		end
	end
	repl_env.print = function(...)
		local str = {}
		for _,v in pairs({...}) do
			table.insert(str, tostring(v))
		end
		output_str(table.concat(str, " "))
	end
	local function handle_repl_line()
		if trim(repl_line):sub(1,1)=="$" then
			local p = io.popen(repl_line, "r")
			if p then
				output_str(p:read("*a"))
				p:close()
			end
			return
		elseif trim(repl_line):sub(-1) == "\\" then
			repl_line = repl_line .. "\n"
			return
		elseif trim(repl_line) == "exit" then
			run = false
		else
			local f,err = loadstring(repl_line)
			repl_line = ""
			if f then
				setfenv(f, repl_env)
				local ok,ret = pcall(f)
				if ok and ret then
					output_str(tostring(ret))
				elseif not ok then
					output_str("Error:" .. tostring(ret))
				end
			else
				output_str("Error:" .. tostring(err))
			end
		end
	end

	local screen_w, screen_h = 80, 25
	w(alternate_on)
	while run do

		w(reset_all)
		local ystart = math.max(#output_history-screen_h, 1)
		local ymax = 0
		for y=ystart,ystart+screen_h do
			local line = output_history[y]
			if line then
				w(line, "\n")
				ymax = y
			end
		end
		w(">", repl_line)
		w(set_cursor_fmt:format(ymax+1, cursor_x+1))

		local key_code, key_resolved = getch.get_mbs(getch.blocking, get_key_table())
		local char = string.char(key_code)
		if key_resolved == "escape" then
			run = false
		elseif key_resolved == "enter" then
			handle_repl_line()
			cursor_x = 1
		elseif key_resolved == "delete" then
			local left = repl_line:sub(1, cursor_x-1)
			local right = repl_line:sub(cursor_x+1)
			repl_line = left .. right
		elseif key_resolved == "backspace" then
			local left = repl_line:sub(1, cursor_x-2)
			local right = repl_line:sub(cursor_x)
			cursor_x = math.max(cursor_x - 1, 1)
			repl_line = left .. right
		elseif key_resolved == "left" then
			cursor_x = math.max(cursor_x-1 ,1)
		elseif key_resolved == "right" then
			cursor_x = math.min(cursor_x+1 ,#repl_line+1)
		elseif key_resolved == "up" then
			if input_history_index then
				input_history_index = math.max(input_history_index - 1, 1)
			else
				input_history_index = #input_history
			end
		elseif key_resolved == "down" then
			if input_history_index then
				input_history_index = math.min(input_history_index + 1, #input_history+1)
				if not input_history[input_history_index] then
					input_history_index = nil
				end
			end
		elseif (not key_resolved) and char:match("%C") then
			local left = repl_line:sub(1, cursor_x-1)
			local right = repl_line:sub(cursor_x)
			repl_line = left .. char .. right
			cursor_x = cursor_x + 1
		end
	end

	w(alternate_off)
end
primitive_repl()
