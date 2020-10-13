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
	return str:match("^%s*")
end

local function trim(str)
   local from = str:match("^%s*()")
   return (from > #str) and "" or str:match(".*%S", from)
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



-- list of buffers currently open
local buffers = {}


-- return a new, empty buffer
local new_file_buffer
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
		{ name="Save to", text="", callback = function(self, buf)
			if #self.text>0 then
				buf:save_to_file(self.text)
				buf.filename = self.text
				buf.name = self.text
				return true
			end
		end},
		{ name="Load from", text="", callback = function(self, buf)
			if #self.text>0 then
				buf:load_from_file(self.text)
				buf.filename = self.text
				buf.name = self.text
				return true
			end
		end},
		{
			name = "Line ending",
			children = {
				{ name = "set line ending to \"\\n\"", callback=function(self, buf)
					buf.line_format="\n"
					return true
				end },
				{ name = "set line ending to \"\\r\\n\"", callback=function(self, buf)
					buf.line_format="\r\n"
					return true
				end },
			}
		},
		{
			name = "Tab width",
			text = tostring(buffer.tab_width),
			callback = function(self, buf)
				local tw = math.floor(tonumber(self.text))
				if tw>=0 and tw<=24 then
					buf.tab_width = tw
					return true
				end
			end
		},
		{ name="Hex Editor" },
		{ name="Toggle Autoindent", value=tostring(buffer.auto_indent), callback = function(self, buf)
			buf.auto_indent = not buf.auto_indent
			self.value = tostring(buf.auto_indent)
			return true
		end },
		{ name="Toggle Line numbers", value=tostring(buffer.auto_indent), callback = function(self, buf)
			buf.line_numbers = not buf.line_numbers
			self.value = tostring(buf.line_numbers)
			return true
		end },
		{ name="Toggle Soft wrap", value=tostring(buffer.soft_wrap), callback = function(self, buf)
			buf.soft_wrap = not buf.soft_wrap
			self.value = tostring(buf.soft_wrap)
			return true
		end },
		{ name="Toggle Hard wrap", value=tostring(buffer.hard_wrap), callback = function(self, buf)
			buf.hard_wrap = not buf.hard_wrap
			self.value = tostring(buf.hard_wrap)
			return true
		end },
		{ name="Close", callback=function(self, buf)
			buf:remove(buffers)
			return true
		end},
	}

	-- all buffers can load content from a file
	function buffer:load_from_file(filepath)
		if file_exists(filepath) then
			new_file_buffer(filepath, self) -- transform self into a file_buffer
			self:load()
			self:content_to_lines()
		end
	end

	-- all buffers can export content to a file
	function buffer:save_to_file(filepath)
		local file = io.open(filepath, "w")
		if file then
			file:close()
			new_file_buffer(filepath, self) -- transform self into a file_buffer
			self:save() -- save to default path
		end
	end

	-- convert the line-bases lines_content back to the string representation content
	function buffer:lines_to_content()
		self.content = table.concat(self.lines, "\n")
	end

	function buffer:content_to_lines()
		self.lines = split_by_pattern(self.content, "\n")
	end
	function buffer:remove(buffers)
		local i
		for k,v in ipairs(buffers) do
			if v == self then
				i = k
				break
			end
		end
		if i and #buffers>1 then
			table.remove(buffers, i)
			if buffers.current_buffer == self then
				buffers.current_buffer = buffers[1]
			end
		end
	end

	return buffer
end

-- return a new file buffer(no file content has been loaded yet!)
function new_file_buffer(filepath, _buffer)
	local file_buffer = _buffer or new_buffer()
	file_buffer.type = "file"
	file_buffer.filepath = filepath -- used when reloading the buffer
	file_buffer.name = filepath

	function file_buffer:save()
		local f = io.open(self.filepath, "w")
		if not f then
			return nil, "Can't open file for writing: " .. tostring(filepath)
		end
		self.modified = false
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

	table.insert(file_buffer.file_menu, 1, {
		name = "Save",
		callback = function(self, buf)
			buf:save()
			return true
		end
	})
	table.insert(file_buffer.file_menu, 2, {
		name = "Load",
		callback = function(self, buf)
			buf:load()
			return true
		end
	})
	file_buffer.file_menu[3].text = filepath
	file_buffer.file_menu[4].text = filepath

	return file_buffer
end


local function new_lua_buffer()
	local lua_buffer = new_buffer()
	lua_buffer.type = "lua"
	lua_buffer.name = "Lua Buffer"

	local output_buffer = new_buffer()
	output_buffer.name = "Lua Buffer Output"
	lua_buffer.output_buffer = output_buffer

	lua_buffer.file_menu = {
		{ name = "Run in editor" },
		{ name = "Save as", text="" },
		{ name = "Save as", text="" },
		{ name = "Run as temporary file" },
		{ name = "View output" },
		{ name = "set output mode..." },
	}
end





local unicode = true
local screen_h = 25
local screen_w = 80

local run = true
local mode = "editor"
local clipboard



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
local function editor_draw(buffer, no_topline)
	-- TODO: no need to redraw these every time
	if no_topline then
		w("\n")
	else
		w(top_line(buffer), "\027[0m\n")
	end
	local lines = content_lines(buffer, buffer.scroll_y, screen_h-2, screen_w)
	for _,line in ipairs(lines) do
		w(line, "\n")
	end

	if buffer.current_line then
		local line_number_width = 0
		if buffer.line_numbers then
			line_number_width = #tostring(#buffer.lines)+1
		end

		local screen_y = buffer.current_line - buffer.scroll_y

		local _,tab_count = buffer.lines[buffer.current_line]:sub(1, buffer.current_column-1):gsub("\t", "")
		local tab_w = 0
		if tab_count > 0 then
			tab_w = tab_count*(buffer.tab_width-1)
		end
		w(set_cursor_fmt:format(screen_y+1, buffer.current_column+line_number_width+tab_w))
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
local function clipboard_copy_cursor(buffer)
	clipboard = buffer.lines[buffer.current_line]:sub(buffer.current_column)
end
local function clipboard_paste_line(buffer)
	if clipboard then
		table.insert(buffer.lines, buffer.current_line, clipboard)
		buffer:lines_to_content()
		buffer.current_column = #clipboard+1
		buffer.modified = true
	end
end
local function clipboard_paste_cursor(buffer)
	if clipboard then
		local line = buffer.lines[buffer.current_line]
		local left = line:sub(1, buffer.current_column-1)
		local right = line:sub(buffer.current_column)
		buffer.lines[buffer.current_line] = left .. clipboard .. right
		buffer.current_column = buffer.current_column + #clipboard
		buffer:lines_to_content()
	end
end
local function indent(buffer)
	buffer.lines[buffer.current_line] = "\t" .. buffer.lines[buffer.current_line]
	buffer:lines_to_content()
end
local function outdent(buffer)
	buffer.lines[buffer.current_line] = buffer.lines[buffer.current_line]:match("^\t?.*")
	buffer:lines_to_content()
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
			{ name = "Copy line", callback=function(self, buf)
				clipboard_copy_line(buf)
				return true
			end},
			{ name = "Copy from cursor", callback=function(self, buf)
				clipboard_copy_cursor(buf)
				return true
			end},
			{ name = "Paste line", callback=function(self, buf)
				clipboard_paste_line(buf)
				return true
			end},
			{ name = "Paste to cursor", callback=function(self, buf)
				clipboard_paste_cursor(buf)
				return true
			end},
			{ name = "Indent" },
			{ name = "Outdent" },
		}
	},
	{
		name = "Buffers",
		children = {}
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

local function generate_buffers_menu()
	local buffers_menu_list = {}
	for i,buffer in ipairs(buffers) do
		local disp_name = buffer.name.."(".. i ..")"
		if buffer == buffers.current_buffer then
			disp_name = i.."* " .. disp_name
		else
			disp_name = i..") " .. disp_name
		end
		table.insert(buffers_menu_list, {
			name = disp_name,
			callback = function(self, buf)
				buffers.current_buffer = buffer
				return true
			end
		})
	end
	table.insert(buffers_menu_list, {
		name = "",
	})
	table.insert(buffers_menu_list, {
		name = "Open file",
		text = "",
		callback = function(self, buf)
			if #self.text>0 then
				local file_buffer = new_file_buffer(self.text)
				file_buffer:load() -- load content from disk,
				file_buffer:content_to_lines() -- convert content to lines
				table.insert(buffers, file_buffer)
				buffers.current_buffer = file_buffer -- change visible buffer to current
				return true
			end
		end
	})
	table.insert(buffers_menu_list, {
		name = "New buffer",
		callback = function(self, buf)
			local buffer = new_buffer() -- create a new buffer
			table.insert(buffers, buffer) -- add to list of available buffer
			buffers.current_buffer = buffer -- change visible buffer to current
			return true
		end
	})
	table.insert(buffers_menu_list, {
		name = "Lua buffer",
		callback = function(self, buf)
			local buffer = new_buffer() -- create a new buffer
			table.insert(buffers, buffer) -- add to list of available buffer
			buffers.current_buffer = buffer -- change visible buffer to current
			return true
		end
	})
	table.insert(buffers_menu_list, {
		name = "Duplicate current",
		callback = function(self, buf)
			local buffer = new_buffer() -- create a new buffer
			buffer.content = buf.content -- copy content string
			buffer:content_to_lines() -- convert content to lines for render
			table.insert(buffers, buffer) -- add to list of available buffer
			buffers.current_buffer = buffer -- change visible buffer to current
			return true
		end
	})
	table.insert(buffers_menu_list, {
		name = "Close all except current",
		callback = function(self, buf)
			for i=1, #buffers do
				if buffers[i] ~= buffers.current_buffer then
					buffers[i]:remove()
				end
			end
			buffers.current_buffer = buffer -- change visible buffer to current
			return true
		end
	})
	return buffers_menu_list
end

local cmenu
local selected
local top_selected
local top_focus
local function menu_enter()
	mode = "menu"
	top_selected = 1
	top_focus = true
	cmenu = nil -- top_menu[top_selected].children
	selected = 1
	top_menu[1].children = buffers.current_buffer.file_menu
	top_menu[3].children = generate_buffers_menu()
end

local function menu_handle_key(key_code, key_resolved)
	if not key_code then
		return
	end
	if key_resolved == "escape" then
		if cmenu then
			cmenu = nil
			top_focus = true
		else
			mode = "editor"
		end
	elseif key_resolved == "up" then
		if cmenu then
			selected = math.max(selected - 1, 1)
		end
	elseif key_resolved == "down" then
		if cmenu then
			selected = math.min(selected + 1, #cmenu)
		end
	elseif key_resolved == "left" then
		if top_focus then
			top_selected = math.max(top_selected - 1, 1)
			selected = 1
		else
			selected = 1
		end
	elseif key_resolved == "right" then
		if top_focus then
			top_selected = math.min(top_selected + 1, #top_menu)
			selected = 1
		elseif cmenu then
			selected = #cmenu
		end
	elseif key_resolved == "enter" then
		if cmenu then
			local item = cmenu[selected]
			if item.callback then
				local new_mode = item:callback(buffers.current_buffer)
				if new_mode == true then
					mode = "editor"
				elseif new_mode then
					mode = new_mode
				end
			elseif item.children then
				item.children.parent = cmenu
				cmenu = item.children
				top_focus = false
				selected = 1
			end
		else
			local item = top_menu[top_selected]
			if item.callback then
				item:callback(buffers.current_buffer)
			end
			cmenu = top_menu[top_selected].children
			top_focus = false
			--top_selected = top_selected
		end
	elseif key_resolved == "backspace" then
		local item = cmenu[selected]
		if item.text then
			item.text = item.text:sub(1, -2)
		end
	end
	if (not key_resolved) and key_code then
		local char = string.char(key_code)
		local item = cmenu[selected]
		if item.text and char:match("%C") then
			item.text = item.text .. char
		end
	end
end

local function menu_draw()
	-- reset sgr, clear screen, set cursor to 1,1
	w(reset_all)
	editor_draw(buffers.current_buffer, true)
	w(set_cursor_fmt:format(1,1))

	for i,menu_item in ipairs(top_menu) do
		w("\027[44m")
		if (i == top_selected) and top_focus then
			w("\027[43m", menu_item.name, "\027[44m")
		else
			w(menu_item.name)
		end
		if i ~= #top_menu then
			w(" | ")
		end
	end
	w("\n\027[0m")

	if cmenu then
		local cursor_x
		for i,menu_item in ipairs(cmenu) do
			if i==selected then
				local line = ("\027[47m\027[34m[ %25s ] - %12s\027[0m\n"):format(menu_item.name, menu_item.text or menu_item.value or "")
				w(line)
				if menu_item.text then
					cursor_x = #line-14
				end
			else
				w(("\027[44m  %25s   - %12s\027[0m\n"):format(menu_item.name, menu_item.text or menu_item.value or ""))
			end
		end
		if cursor_x then
			local cursor_y = selected + 2
			w(set_cursor_fmt:format(cursor_y, cursor_x))
		end
	end

	-- make sure the terminal got everything
	flush()
end






-- handle a resolved key sequence from the terminal for the editor
local function editor_handle_resolved(buffer, key_resolved)
	if key_resolved == "escape" then
		menu_enter()
	end
	local modify_cursor = false
	if buffer.current_line then
		if key_resolved == "enter" then
			local line = buffer.lines[buffer.current_line]
			local line_left = line:sub(1, buffer.current_column-1)
			local line_right = line:sub(buffer.current_column)
			buffer.lines[buffer.current_line] = line_left
			local whitespace = get_indent(line_left) or ""
			if buffer.auto_indent and #whitespace>0 then
				table.insert(buffer.lines, buffer.current_line+1, whitespace..line_right)
				buffer.current_column = #buffer.lines[buffer.current_line]+1
			else
				table.insert(buffer.lines, buffer.current_line+1, line_right)
				buffer.current_column = 1
			end
			buffer.current_line = buffer.current_line + 1
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
			-- TODO: Use indent function, make indent style selectable
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

	return file_buffer, #buffers
end


local function primitive_repl()
	w(alternate_off)

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

		buffers = buffers,
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
			setfenv(f, repl_env)
			if f then
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
	while run do
		local key_code, key_resolved = getch.get_mbs(getch.blocking, get_key_table())
		local char = string.char(key_code)
		if key_resolved == "escape" then
			run = false
		elseif key_resolved == "enter" then
			handle_repl_line()
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
			local left = repl_line:sub(1, cursor_x)
			local right = repl_line:sub(cursor_x+1)
			repl_line = left .. char .. right
		end
	end

	w(alternate_on)
end

local repl_output_history = {}
local repl_input_history = {}
local repl_input_history_i = 1
local repl_line = ""
local function repl_handle_key(key_code, key_resolved)
	if key_resolved == "up" then
		repl_input_history_i = math.max(repl_input_history_i-1, 1)
		repl_line = repl_input_history[repl_input_history_i] or ""
	elseif key_resolved == "down" then
		repl_input_history_i = math.min(repl_input_history_i+1, #repl_input_history + 1)
		repl_line = repl_input_history[repl_input_history_i] or ""
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

		if (repl_line == "editor") or (repl_line == "exit") then
			mode = "editor"
			return
		elseif repl_line == "menu" then
			menu_enter()
			return
		elseif repl_line == "_menu" then
			mode = "menu"
			return
		end
		if repl_line:sub(1,1)=="=" then
			repl_line = "return " .. repl_line:sub(2)
		end
		if repl_line:sub(-1)=="\\" then
			repl_line = repl_line:sub(1, -2) .. "\n"
			return
		end
		if repl_line:sub(1,1)=="$" then
			local p,err = io.popen(repl_line:sub(2))
			if p then
				local content = p:read("*a")
				table.insert(repl_output_history, ">"..content:gsub("\n", "\n>"))
			else
				table.insert(repl_output_history, "popen failed:" .. tostring(err))
			end
			table.insert(repl_input_history, repl_line)
			repl_input_history_i = #repl_input_history
			repl_line = ""
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
		table.insert(repl_input_history, repl_line)
		repl_input_history_i = #repl_input_history
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
	--w(("="):rep(80),"\n")
	local max_h = 20
	local min_i = #repl_output_history-max_h
	for i,v in ipairs(repl_output_history) do
		if i>min_i then
			w(v,"\n")
		end
	end
	--w(("="):rep(80),"\n")
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

			-- reset sgr, clear screen, set cursor to 1,1
			w(reset_all)
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
