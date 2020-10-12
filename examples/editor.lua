#!/usr/bin/lua5.1
local getch = require("lua-getch")

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

-- returns true if a filepath exits(can be opened for reading), nil otherwise
local function file_exists(filepath)
	local f = io.open(filepath, "r")
	if f then
		f:close()
		return true
	end
end

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

-- soft-wrap a line(split into multiple lines)
local function soft_wrap_line(line, len)
	return line:sub(1, len) -- TODO: wrap at words, insert newline for rendering, decrease view height, scroll_x
end

-- hard-wrap a line(scrollable)
local function hard_wrap_line(line, len, scroll_x)
	return line:sub(1+scroll_x, len+scroll_x)
end

-- return the whitespace used to "indent" this line
local function get_indent(str)
	return str:match("^(%s+)%S")
end


-- return a new, empty buffer
local function new_buffer()
	local buffer = {}

	buffer.content = ""
	buffer.lines = {}
	buffer.type = "buffer"

	buffer.name = "Empty buffer" -- display name
	buffer.line_format = "\n" -- could also be \r\n
	buffer.replace_control = "#" -- control characters are replaced with this
	buffer.replace_tabs = true -- replace tabs in display output with spaces
	buffer.modified = false

	buffer.current_line = nil -- current line(y-value) of cursor in this buffer
	buffer.current_column = nil -- current column(x-value) of cursor in this buffer
	buffer.scroll_x = 0 -- current scroll position in this buffer
	buffer.scroll_y = 0
	buffer.line_numbers = true -- show line numbers when displaying this buffer?
	buffer.tab_width = 4 -- tab width for this buffer
	buffer.soft_wrap = false -- soft-wrap lines? TODO: NYI
	buffer.hard_wrap = true -- hard-wrap lines?
	buffer.auto_indent = true -- auto-indent new lines?

	buffer.file_menu = {
		{ name="Reload" },
		{ name="Save as", text="" },
		{
			name = "Line ending",
			children = {
				{ name = "set line ending to \"\\n\"", callback=function()
					buffer.line_format="\n"
					return true
				end },
				{ name = "set line ending to \"\\r\\n\"", callback=function()
					buffer.line_format="\r\n"
					return true
				end },
			}
		},
		{
			name = "Tab width",
			children = {
				{ name = "set tab width to 1", callback=function() buffer.tab_width=1; return true end },
				{ name = "set tab width to 2", callback=function() buffer.tab_width=2; return true end },
				{ name = "set tab width to 4", callback=function() buffer.tab_width=4; return true end },
				{ name = "set tab width to 8", callback=function() buffer.tab_width=8; return true end },
			}
		},
		{ name="Close", callback=function() if buffer.remove then buffer:remove() end end},
	}

	-- convert the line-bases lines_content back to the string representation content
	function buffer:lines_to_content()
		self.content = table.concat(self.lines, "\n")
	end

	function buffer:content_to_lines()
		self.lines = split_by_pattern(self.content, "\n")
	end

	return buffer
end

-- return a new file buffer(no file content has been loaded yet!)
local function new_file_buffer(filepath)
	local file_buffer = new_buffer()
	file_buffer.type = "file"
	file_buffer.filepath = filepath -- used when reloading the buffer
	file_buffer.name = filepath

	function file_buffer:save()
		local f = io.open(self.filepath, "w")
		if not f then
			return nil, "Can't open file for writing: " .. tostring(filepath)
		end
		self:lines_to_content()
		f:write(self.content)
		f:close()
	end
	function file_buffer:load()
		local f = io.open(self.filepath, "r")
		if not f then
			return nil, "Can't open file for reading: " .. tostring(filepath)
		end
		self.content = f:read("*a")
		self:content_to_lines()
		self.modified = false
		f:close()
	end

	return file_buffer
end




local unicode = true
local screen_h = 25
local screen_w = 80

local run = true
local mode = "editor"
local clipboard


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


-- get the top menu line.
local function top_line(buffer)
	if buffer.current_line then
		return bg_white..fg_black..("%s: %s[at line %d, column %d%s]"):format(
			buffer.type,
			buffer.name,
			buffer.current_line,
			buffer.current_column or 0,
			(buffer.modified and ", modified" or "")
		)
	else
		return bg_white..fg_black..("%s: %s"):format(
			buffer.type,
			buffer.name
		)
	end
end

-- return a single unmodified line from a buffer as a display line
local function content_lines(buffer, lines_offset, line_count, line_len)
	local line_number_width = 0
	if buffer.line_numbers then
		line_number_width = #tostring(#buffer.lines)
	end
	local display_lines = {}
	for y=1, line_count do
		local line_num = y+lines_offset
		local line = buffer.lines[line_num]
		if line then -- convert unmodified buffer line to a display line
			if buffer.replace_tabs then
				line = line:gsub("\t", (" "):rep(buffer.tab_width))
				line = line:gsub("%c", buffer.replace_control)
			end
			if buffer.replace_control then
				line = line:gsub("%c", buffer.replace_control)
			end
			if buffer.soft_wrap then
				line = soft_wrap_line(line, line_len-line_number_width)
			end
			if buffer.hard_wrap then
				line = hard_wrap_line(line, line_len-line_number_width-1, buffer.scroll_x)
			end
			if buffer.line_numbers and (buffer.current_line == line_num) then
				line = fg_cyan..bg_white..("%"..line_number_width.."d"):format(line_num).."\027[0m>"..line
			elseif buffer.line_numbers then
				line = fg_blue..bg_white..("%"..line_number_width.."d"):format(line_num).."\027[0m "..line
			end

			table.insert(display_lines, line)
		end
	end
	return display_lines
end

-- output strings to the terminal(stderr) for graphics output
local function w(...)
	io.stderr:write(...)
end
local function flush() -- needs to match w()
	io.stderr:flush()
end

-- simple drawing routine using ANSI escape sequences
local function editor_draw(buffer)
	-- reset sgr, clear screen, set cursor to 1,1
	w(reset_all)

	-- TODO: no need to redraw these every time
	w(top_line(buffer), "\n")
	local lines = content_lines(buffer, buffer.scroll_y, screen_h-2, screen_w)
	for _,line in ipairs(lines) do
		w(line, "\n")
	end

	if buffer.current_line then
		local line_number_width = 0
		if buffer.line_numbers then
			line_number_width = #tostring(#buffer.lines)
		end

		local screen_y = buffer.current_line - buffer.scroll_y

		local _,tab_count = buffer.lines[buffer.current_line]:sub(1, buffer.current_column-1):gsub("\t", "")
		local tab_w = 0
		if tab_count > 0 then
			tab_w = tab_count*(buffer.tab_width-1)
		end
		w(set_cursor_fmt:format(screen_y+1, buffer.current_column+line_number_width+1+tab_w))
	end

	-- make sure the terminal got everything
	flush()
end

local function clipboard_cut_line(buffer)
	clipboard = table.remove(buffer.lines, buffer.current_line)
	buffer:lines_to_content()
	buffer.current_column = 1
	buffer.modified = true
end
local function clipboard_copy_line(buffer)
	clipboard = buffer.lines[buffer.current_line]
end
local function clipboard_paste_line(buffer)
	if clipboard then
		table.insert(buffer.lines, buffer.current_line, clipboard)
		buffer:lines_to_content()
		buffer.current_column = #clipboard+1
		buffer.modified = true
	end
end

-- handle a key from the terminal for the menu
local top_menu = {
	{
		name = "File",
		children = {},
	},
	{
		name = "Edit",
		children = {
			{ name = "Copy line" },
			{ name = "Copy from cursor" },
			{ name = "Paste" },
			{ name = "Indent" },
			{ name = "Outdent" },
		}
	},
	{
		name = "Buffers",
		children = {

		}
	},
	{
		name = "REPL",
		callback = function()
			mode = "repl"
		end
	},
	{
		name = "Exit",
		callback = function()
			run = false
		end
	}
}
local cmenu = top_menu
local selected = 1
local function menu_handle_key(key_code, key_resolved)
	local item = cmenu[selected]
	if not key_code then
		return
	end
	if key_resolved == "escape" then
		if cmenu == top_menu then
			mode = "editor"
			selected = 1
		elseif cmenu.parent then
			local parent = cmenu.parent
			cmenu.parent = nil
			cmenu = parent
			selected = 1
		end
	elseif key_resolved == "up" then
		selected = math.max(selected - 1, 1)
	elseif key_resolved == "down" then
		selected = math.min(selected + 1, #cmenu)
	elseif key_resolved == "enter" then
		if item.callback and item:callback() then
			mode = "editor"
		elseif item.children then
			item.children.parent = cmenu
			cmenu = item.children
			selected = 1
		end
	elseif key_resolved == "backspace" then
		if item.text then
			item.text = item.text:sub(1, -2)
		end
	end
	if (not key_resolved) and key_code then
		local char = string.char(key_code)
		if item.text and char:match("%C") then
			item.text = item.text .. char
		end
	end
end

local function menu_draw()
	-- reset sgr, clear screen, set cursor to 1,1
	w(reset_all)

	w("Menu\n\n")
	for i,menu_item in ipairs(cmenu) do
		if (i==selected) and menu_item.text then
			w(" [", menu_item.name, "]:" .. menu_item.text .. "\n")
		elseif i==selected then
			w(" [", menu_item.name, "]\n")
		else
			w("  ", menu_item.name, " \n")
		end
	end

	-- make sure the terminal got everything
	flush()
end






-- handle a resolved key sequence from the terminal for the editor
local function editor_handle_resolved(buffer, key_resolved)
	if key_resolved == "escape" then
		mode = "menu"
		cmenu = top_menu
		selected = 1
		top_menu[1].children = buffer.file_menu
	end
	local modify_cursor = false
	if buffer.current_line then
		if key_resolved == "enter" then
			local line = buffer.lines[buffer.current_line]
			local line_left = line:sub(1, buffer.current_column-1)
			local line_right = line:sub(buffer.current_column)
			buffer.lines[buffer.current_line] = line_left
			if buffer.auto_indent and (#line_right>0) and (#line_left>0) then
				local indent = get_indent(line_left) or ""
				table.insert(buffer.lines, buffer.current_line+1, indent..line_right)
			else
				table.insert(buffer.lines, buffer.current_line+1, line_right)
			end
			buffer.current_line = buffer.current_line + 1
			buffer.current_column = 1
			modify_cursor = true
			buffer:lines_to_content()
			buffer.modified = true
		elseif key_resolved == "delete" then
			local line = buffer.lines[buffer.current_line]
			local line_left = line:sub(1, buffer.current_column-1)
			local line_right = line:sub(buffer.current_column+1)
			if #line_right>0 then
				local new_line = line_left .. line_right
				buffer.lines[buffer.current_line] = new_line
			else
				local next_line = table.remove(buffer.lines, buffer.current_line+1) or ""
				buffer.lines[buffer.current_line] = line_left .. next_line
			end
			buffer:lines_to_content()
			buffer.modified = true
			modify_cursor = true
		elseif key_resolved == "backspace" then
			local line = buffer.lines[buffer.current_line]
			local line_left = line:sub(1, buffer.current_column-2)
			local line_right = line:sub(buffer.current_column)
			if buffer.current_column>1 then
				local new_line = line_left .. line_right
				buffer.lines[buffer.current_line] = new_line
				buffer.current_column = buffer.current_column - 1
			else
				if buffer.current_line > 1 then
					table.remove(buffer.lines, buffer.current_line)
					local prev_line = buffer.lines[buffer.current_line-1]
					buffer.lines[buffer.current_line-1] = prev_line .. line
					buffer.current_column = #prev_line+1
					buffer.current_line = buffer.current_line - 1
				end
			end
			buffer:lines_to_content()
			buffer.modified = true
			modify_cursor = true
		elseif key_resolved == "up" then
			buffer.current_line = buffer.current_line-1
			buffer.scroll_x = 0
			modify_cursor = true
		elseif key_resolved == "down" then
			buffer.current_line = buffer.current_line+1
			buffer.scroll_x = 0
			modify_cursor = true
		elseif key_resolved == "left" then
			buffer.current_column = buffer.current_column-1
			modify_cursor = true
		elseif key_resolved == "right" then
			buffer.current_column = buffer.current_column+1
			modify_cursor = true
		elseif key_resolved == "pos1" then
			buffer.current_column = 1
			modify_cursor = true
		elseif key_resolved == "end" then
			buffer.current_column = #buffer.lines[buffer.current_line]+1
			modify_cursor = true
		elseif key_resolved == "tab" then
			local line = buffer.lines[buffer.current_line]
			local line_left = line:sub(1, buffer.current_column-1)
			local line_right = line:sub(buffer.current_column)
			local new_line = line_left .. "\t" .. line_right
			buffer.lines[buffer.current_line] = new_line
			buffer:lines_to_content()
			buffer.modified = true
			buffer.current_column = buffer.current_column + 1
		elseif key_resolved == "ctrl-k" then
			clipboard_cut_line(buffer)
		elseif key_resolved == "ctrl-u" then
			clipboard_paste_line(buffer)
		end
		if modify_cursor then
			buffer.current_line = math.max(math.min(buffer.current_line, #buffer.lines), 1)
			buffer.current_column = math.max(math.min(buffer.current_column, #buffer.lines[buffer.current_line]+1), 1)
		end
		-- TODO: detect if buffer.current_line is visible, automatically scroll
	end
end

-- handle a regular key from the terminal for the editor
local function editor_handle_key(buffer, key_code, key_resolved)
	if key_resolved then
		return editor_handle_resolved(buffer, key_resolved)
	end
	local char = string.char(key_code)
	if (buffer.current_line) and char:match("%C") then
		local line = buffer.lines[buffer.current_line]
		local line_left = line:sub(1, buffer.current_column-1)
		local line_right = line:sub(buffer.current_column)
		local new_line = line_left .. char .. line_right
		buffer.lines[buffer.current_line] = new_line
		buffer:lines_to_content()
		buffer.modified = true
		buffer.current_column = buffer.current_column + 1
	end
end

-- list of buffers currently open
local buffers = {}


-- create a new file buffer, load content from file, and append to buffer list
local function add_file_buffer(filepath)
	-- add a buffer that also can save/load from a file
	local file_buffer = new_file_buffer(filepath)

	file_buffer:load() -- load content from disk,
	file_buffer:content_to_lines() -- convert content to lines
	table.insert(buffers, file_buffer)
	if not buffers.current_buffer then
		buffers.current_buffer = file_buffer
	end

	function file_buffer:remove()
		local i
		for k,v in ipairs(buffers) do
			if v == self then
				i = k
				break
			end
		end
		table.remove(buffers, i)
		if buffers.current_buffer == self then
			buffers.current_buffer = buffers[1]
		end
	end

	return file_buffer, #buffers
end



local repl_output_history = {}
local repl_input_history = {}
local repl_input_history_i = 1
local repl_line = ""
local function repl_handle_key(key_code, key_resolved)
	if key_resolved == "up" then
		if repl_input_history_i>1 then
			repl_input_history_i = repl_input_history_i-1
			repl_line = repl_input_history[repl_input_history_i]
		end
	elseif key_resolved == "down" then
		if repl_input_history_i<#repl_input_history then
			repl_input_history_i = repl_input_history_i+1
			repl_line = repl_input_history[repl_input_history_i]
		end
	elseif key_resolved == "enter" then
		local env = {}
		for k,v in pairs(getfenv()) do
			env[k] = v
		end
		env.add_file_buffer = add_file_buffer
		env.buffers = buffers

		function env.print(...)
			local output = {}
			for _, str in pairs({...}) do
				table.insert(output, tostring(str))
			end
			table.insert(repl_output_history, table.concat(output, " "))
		end
		function env.clear()
			repl_output_history = {}
		end

		if repl_line == "editor" then
			mode = "editor"
		elseif repl_line == "menu" then
			mode = "menu"
		end
		if repl_line:sub(1,1)=="=" then
			repl_line = "return " .. repl_line:sub(2)
		end
		if repl_line:sub(-1)=="\\" then
			repl_line = repl_line:sub(1, -2) .. "\n"
			return
		end
		local f,err = loadstring(repl_line, "REPL")
		if f then
			setfenv(f, env)
			local ok,ret = pcall(f)
			if ok and ret then
				table.insert(repl_output_history, "Returned: " .. tostring(ret))
			elseif not ok then
				table.insert(repl_output_history, "Error: " .. tostring(ret))
			end
		else
			table.insert(repl_output_history, "loadstring() failed: " .. tostring(err))
		end
		repl_line = ""
	elseif key_resolved == "backspace" then
		repl_line = repl_line:sub(1, -2)
	elseif (not key_resolved) and key_code then
		local char = string.char(key_code)
		if char:match("%C") then
			repl_line = repl_line .. char
		end
	end
end
local function repl_draw()
	-- reset sgr, clear screen, set cursor to 1,1
	w(reset_all)

	w("REPL\n")
	w(("="):rep(80),"\n")
	local max_h = 20
	local min_i = #repl_output_history-max_h
	for i,v in ipairs(repl_output_history) do
		if i>min_i then
			w(v,"\n")
		end
	end
	w(("="):rep(80),"\n")
	w(">"..repl_line)
end



local function main()
	-- parse arguments(load files)
	for _,arg_str in ipairs(arg) do
		if file_exists(arg_str) then
			add_file_buffer(arg_str)
		else
			print("Can't open file:", arg_str)
			os.exit(1)
		end
	end
	-- TODO: create new buffer?
	if #buffers == 0 then
		print("Must open an existing file!")
		os.exit(1)
	end

	-- Enable alternative screen buffer
	w(alternate_on)

	while run do
		local buffer = buffers.current_buffer
		if mode == "editor" then
			buffer.current_line = buffer.current_line or 1
			buffer.current_column = buffer.current_column or 1
			editor_draw(buffer)
		elseif mode == "repl" then
			repl_draw()
		elseif mode == "menu" then
			menu_draw()
		end
		local key_code, key_resolved = getch.get_mbs(getch.blocking, get_key_table())
		if mode == "menu" then
			menu_handle_key(key_code, key_resolved)
		elseif mode == "repl" then
			repl_handle_key(key_code, key_resolved)
		elseif mode == "editor" then
			editor_handle_key(buffer, key_code, key_resolved)
		end
	end

	-- TODO: Check for unsaved changes

	-- Disable alternative screen buffer
	w(alternate_off)

	-- make sure outstanding (escape sequence) characters are received
	flush()

end

-- main "event loop"
main()
