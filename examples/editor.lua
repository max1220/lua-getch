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


local menu_item_file_save_to = {
	name="Save to",
	text="",
	callback = function(item, buf)
		if #item.text>0 then
			buf:save_to_file(item.text)
			return true
		end
	end,
	update = function(item, buf)
		item.text = buf.filepath
	end
}
local menu_item_file_save = {
	name = "Save",
	callback = function(self, buf)
		buf:save()
		return true
	end
}
local menu_item_file_load_from = {
	name="Load from",
	text="",
	callback = function(item, buf)
		if #item.text>0 then
			buf:load_from_file(item.text)
			return true
		end
	end,
	update = function(item, buf)
		item.text = buf.filepath
	end
}
local menu_item_file_load = {
	name = "Load",
	callback = function(self, buf)
		buf:load()
		return true
	end
}
local menu_item_file_line_ending = {
	name = "Line ending",
	callback = function(item,buf)
		if buf.line_format=="\n" then
			buf.line_format="\n"
		else
			buf.line_format="\r\n"
		end
	end,
	update = function(item, buf)
		item.value = (buf.line_format=="\n") and "\\n" or "\\r\\n"
	end
}
local menu_item_file_tab_width = {
	name = "Tab width",
	callback = function(item, buf)
		local tw = tonumber(item.text)
		if tw and (tw>=0) and (tw<=24) then
			buf.tab_width = tw
			return true
		end
	end,
	update = function(item, buf)
		item.value = tostring(buf.tab_width)
	end
}
local menu_item_file_autoindent = {
	name="Toggle Autoindent",
	callback = function(item, buf)
		buf.auto_indent = not buf.auto_indent
		return true
	end,
	update = function(item, buf)
		item.value = tostring(buf.auto_indent)
	end
}
local menu_item_file_linenumbers = {
	name="Toggle Line numbers",
	callback = function(item, buf)
		buf.line_numbers = not buf.line_numbers
		return true
	end,
	update = function(item, buf)
		item.value = tostring(buf.line_numbers)
	end
}
local menu_item_file_soft_wrap = {
	name="Toggle Soft wrap",
	callback = function(item, buf)
		buf.soft_wrap = not buf.soft_wrap
		return true
	end,
	update = function(item, buf)
		item.value = tostring(buf.soft_wrap)
	end
}
local menu_item_file_hard_wrap = {
	name="Toggle Hard wrap",
	callback = function(item, buf)
		buf.hard_wrap = not buf.hard_wrap
		return true
	end,
	update = function(item, buf)
		item.value = tostring(buf.hard_wrap)
	end
}
local menu_item_file_close = {
	name="Close",
	callback = function(item, buf)
		buf:remove(buffers)
		return true
	end
}

-- return a new, empty buffer
function buffers:new_buffer()
	local buffer = {}

	buffer.content = ""
	buffer.lines = {""}
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
		menu_item_file_save_to,
		menu_item_file_load_from,
		menu_item_file_line_ending,
		menu_item_file_tab_width,
		menu_item_file_autoindent,
		menu_item_file_linenumbers,
		menu_item_file_soft_wrap,
		menu_item_file_hard_wrap,
		menu_item_file_close,
	}

	-- all buffers can load content from a file
	function buffer.load_from_file(buf, filepath)
		if file_exists(filepath) then
			self:new_file_buffer(filepath, buf) -- transform self into a file_buffer
			buf:load()
			buf:content_to_lines()
			buf.filename = filepath
			buf.name = filepath
		end
	end

	-- all buffers can export content to a file
	function buffer.save_to_file(buf, filepath)
		local file = io.open(filepath, "w")
		if file then
			file:close()
			buf:new_file_buffer(filepath, buf) -- transform self into a file_buffer
			buf:save() -- save to default path
			buf.filename = filepath
			buf.name = filepath
		end
	end

	-- convert the line-bases lines_content back to the string representation content
	function buffer.lines_to_content(buf)
		buf.content = table.concat(buf.lines, "\n")
	end

	function buffer.content_to_lines(buf)
		buf.lines = split_by_pattern(buf.content, "\n")
	end

	return buffer
end

-- return a new file buffer(no file content has been loaded yet!)
function buffers:new_file_buffer(filepath, _buffer)
	local file_buffer = _buffer or self:new_buffer()
	file_buffer.type = "file"
	file_buffer.filepath = filepath -- used when reloading the buffer
	file_buffer.name = filepath

	function file_buffer.save(buf)
		local f = io.open(buf.filepath, "w")
		if not f then
			return nil, "Can't open file for writing: " .. tostring(filepath)
		end
		buf.modified = false
		buf:lines_to_content()
		f:write(buf.content)
		f:close()
	end
	function file_buffer.load(buf)
		local f = io.open(buf.filepath, "r")
		if not f then
			return nil, "Can't open file for reading: " .. tostring(filepath)
		end
		buf.content = f:read("*a")
		buf:content_to_lines()
		buf.modified = false
		f:close()
	end


	file_buffer.file_menu = {
		menu_item_file_save,
		menu_item_file_save_to,
		menu_item_file_load,
		menu_item_file_load_from,
		menu_item_file_line_ending,
		menu_item_file_tab_width,
		menu_item_file_autoindent,
		menu_item_file_linenumbers,
		menu_item_file_soft_wrap,
		menu_item_file_hard_wrap,
		menu_item_file_close,
	}

	return file_buffer
end

-- return a new Lua buffer(used for executing Lua, viewing results)
function buffers:new_lua_buffer()
	local lua_buffer = self:new_buffer()
	lua_buffer.type = "lua"
	lua_buffer.name = "Lua Buffer"

	local output_buffer = self:new_buffer()
	output_buffer.name = "Lua Buffer Output"
	lua_buffer.output_buffer = output_buffer

	lua_buffer.file_menu = {
		{ name = "Run in editor" },
		{ name = "Save as", text="" },
		{ name = "Run as temporary file" },
		{ name = "View output" },
		{ name = "set output mode..." },
	}
end

-- remove a buffer from the buffer list. If found, buffer is removed and returned
function buffers:remove(buf)
	for k,v in ipairs(self) do
		if (v == buf) and (#self>1) then
			table.remove(self, k)
			if buffers.current_buffer == self then
				buffers.current_buffer = buffers[1]
			end
			return buf
		end
	end
end

-- create a new buffer with optional content, append to buffer list
function buffers:add_new_buffer(content)
	local bufffer = self:new_buffer()
	bufffer.content = tostring(content or "")
	bufffer:content_to_lines()
	table.insert(buffers, bufffer)
	return bufffer, #buffers
end

-- create a new file buffer, load content from file, and append to buffer list
function buffers:add_new_file_buffer(filepath)
	local file_buffer = self:new_file_buffer(filepath)
	file_buffer:load() -- load content from disk,
	file_buffer:content_to_lines() -- convert content to lines
	table.insert(buffers, file_buffer)
	return file_buffer, #buffers
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

















local menu_item_edit_clipboard_copy_line = {
	name = "Copy line",
	callback = function(item, buf)
		clipboard = buf.lines[buf.current_line]
		return true
	end
}
local menu_item_edit_clipboard_copy_cursor = {
	name = "Copy from cursor",
	callback = function(item, buf)
		clipboard = buf.lines[buf.current_line]:sub(buf.current_column)
		return true
	end
}
local menu_item_edit_clipboard_cut_line = {
	name = "Cut line",
	callback = function(item, buf)
		clipboard = table.remove(buf.lines, buf.current_line)
		buf:lines_to_content()
		if clipboard then
			buf:lines_to_content()
			buf.current_column = 1
			buf.modified = true
			return true
		end
	end
}
local menu_item_edit_clipboard_paste_line = {
	name = "Paste line",
	callback = function(item, buf)
		if clipboard then
			table.insert(buf.lines, buf.current_line, clipboard)
			buf:lines_to_content()
			buf.current_column = #clipboard+1
			buf.modified = true
			return true
		end
	end
}
local menu_item_edit_clipboard_paste_cursor = {
	name = "Paste to cursor",
	callback = function(item, buf)
		if clipboard then
			local line = buf.lines[buf.current_line]
			local left = line:sub(1, buf.current_column-1)
			local right = line:sub(buf.current_column)
			buf.lines[buf.current_line] = left .. clipboard .. right
			buf.current_column = buf.current_column + #clipboard
			buf:lines_to_content()
			return true
		end
	end
}
local menu_item_edit_indent = {
	name = "Indent",
	callback = function(item, buf)
		buf.lines[buf.current_line] = "\t" .. buf.lines[buf.current_line]
		buf:lines_to_content()
		return true
	end
}
local menu_item_edit_outdent = {
	name = "Outdent",
	callback = function(item, buf)
		buf.lines[buf.current_line] = buf.lines[buf.current_line]:match("^\t?.*")
		buf:lines_to_content()
		return true
	end
}


local menu_item_buffers_open_file = {
	name = "Open file",
	text = "",
	callback = function(item, buf)
		if #item.text>0 then
			buffers.current_buffer = buffers:add_new_file_buffer(item.text)
			return true
		end
	end
}
local menu_item_buffers_new_buffer = {
	name = "New buffer",
	callback = function(item, buf)
		buffers.current_buffer = buffers:add_new_buffer()
		return true
	end
}
local menu_item_buffers_duplicate_buffer = {
	name = "Duplicate current",
	callback = function(item, buf)
		buffers.current_buffer = buffers:add_new_buffer(buf.content)
		return true
	end
}
local menu_item_buffers_close_others = {
	name = "Close all except current",
	callback = function(item, buf)
		for i=1, #buffers do
			if buffers[i] ~= buffers.current_buffer then
				buffers[i]:remove()
			end
		end
		return true
	end
}



-- the top-level menu structire
local top_menu = {
	{
		name = "File",
		children = {}, -- this menu is stored buffers.current_buffer
	},
	{
		name = "Edit",
		children = {
			menu_item_edit_clipboard_copy_line,
			menu_item_edit_clipboard_copy_cursor,
			menu_item_edit_clipboard_cut_line,
			menu_item_edit_clipboard_paste_line,
			menu_item_edit_clipboard_paste_cursor,
			menu_item_edit_indent,
			menu_item_edit_outdent,
		},
	},
	{
		name = "Buffers",
		children = {
			menu_item_buffers_open_file,
			menu_item_buffers_new_buffer,
			menu_item_buffers_duplicate_buffer,
			menu_item_buffers_close_others,
			{ name = "" }, -- don't remove!
			update = function(item, buf)
				local insert_i = #item
				for i,menu_entry in ipairs(item) do
					if menu_entry.name=="" then
						insert_i = i
					end
				end
				for i,buffer in ipairs(buffers) do
					local disp_name = buffer.name.."(".. i ..")"
					if buffer == buffers.current_buffer then
						disp_name = i.."* " .. disp_name
					else
						disp_name = i..") " .. disp_name
					end
					item[i+insert_i] = {
						name = disp_name,
						callback = function(self, buf)
							buffers.current_buffer = buffer
							return true
						end
					}
				end
			end
		}
	},{
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




local cmenu
local selected
local top_selected
local top_focus
local function top_menu_enter()
	mode = "menu"
	top_selected = 1
	top_focus = true
	cmenu = nil -- top_menu[top_selected].children
	selected = 1
	top_menu[1].children = buffers.current_buffer.file_menu
	top_menu[3].children:update()
end
local function sub_menu_exit()
	cmenu = nil
	top_focus = true
end
local function sub_menu_enter(submenu)
	submenu.parent = cmenu
	cmenu = submenu
	selected = 1
end
local function sub_menu_up()
	if cmenu.parent then
		error("TODO") -- TODO
		cmenu = cmenu.parent
	else
		sub_menu_exit()
	end
end

local function menu_handle_key(key_code, key_resolved)
	if not key_code then
		return
	end
	if key_resolved == "escape" then
		if cmenu then
			sub_menu_up()
			return
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
				top_focus = false
				sub_menu_enter(item.children)
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
	if cmenu and (not key_resolved) and key_code then
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
			w("\027[47m\027[34m ", menu_item.name, " \027[0m\027[44m")
		else
			w(" ", menu_item.name, " ")
		end
		if i ~= #top_menu then
			--w(" | ")
			w("  ")
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
		top_menu_enter()
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

		if repl_line == "exit" then
			mode = "editor"
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
			buffers:add_file_buffer(arg_str)
		else
			print("Can't open file:", arg_str)
			os.exit(1)
		end
	end
	-- TODO: create new buffer?
	if #buffers == 0 then
		buffers:add_new_buffer()
	end
	buffers.current_buffer = assert(buffers[1])

	-- Enable alternative screen buffer
	w(alternate_on)

	while run do
		local buffer = buffers.current_buffer
		if not buffer then break end
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
