local getch = require("lua-getch")
--luacheck: ignore self

-- Utillities for handling terminal input/output
local term = {}

-- terminal dimensions(Automatically attempted to set by term:get_term_size())
term.rows = 80
term.cols = 25

-- function used to write output to the terminal
term.write = io.write
term.flush = io.flush

-- print function that uses only term.write
function term:print(...)
	self.write(tostring(...)) -- write first argument
	for i=2, select("#", ...) do -- write remaining arguments tab separated
		self.write("\t"..tostring(select(i, ...)))
	end
	self.write("\n") -- output newline
end

-- output a single formatted line
function term:printf(fmt, ...)
	self:print(fmt:format(...))
end

-- output a single line, at the specified position
function term:print_at(ox,oy, ...)
	term.write(self:esc_pos(ox,oy))
	self:print(...)
end

-- output list of lines to the screen, at the specified position
function term:print_lines_at(ox,oy, lines)
	for i,line in ipairs(lines) do
		self:print_at(ox, oy+i-1, line)
	end
end

-- get the terminal size
-- todo: replace with getch-based getting terminal size
function term:get_term_size()
	local f = io.popen("stty size")
	if not f then
		return
	end
	local rows,cols = f:read("*a"):match("^(%d+)%s+(%d+)")
	rows,cols = tonumber(rows), tonumber(cols)
	if rows then
		self.rows = rows
		self.cols = cols
	end
end

-- get the top-left position of the rectangle cw,ch centered in the terminal.
function term:get_center_rect_position(cw,ch)
	local cx,cy
	if cw then
		cx = math.floor((self.cols/2)-(cw/2))
	end
	if ch then
		cy = math.floor((self.rows/2)-(ch/2))
	end
	return cx,cy
end

-- get the "set cursor position" escape sequence
function term:esc_pos(tx, ty)
	return "\027[" .. (tonumber(ty) or 1) .. ";" .. (tonumber(tx) or 1) .. "H"
end

-- clear the entire screen
term.esc_clear = "\027[2J"

-- reset graphics rendition(reset color, bold etc. to default)
term.esc_reset_sgr = "\027[0m"

-- get the escape sequence for setting the specified color
function term:esc_color_16(color, bright, fg)
	local colors = { black = 0, red = 1, green = 2, yellow = 3, blue = 4, magenta = 5, cyan = 6, white = 7 }
	if (not colors[color]) and (color:sub(1,6)=="bright") then
		bright = true
		color = color:sub(8)
	end
	local i = assert(colors[color])
	i = i + ((bright and 90) or 30)
	i = i + ((fg and 0) or 10)
	return "\027["..i.."m"
end

-- enable or disable the alternate screen buffer,
-- to preserve non-graphical terminal content.
function term:esc_alternate_screenbuffer(enable)
	if enable then
		-- enable alternate screen buffer
		return "\027[?1049h"
	else
		-- disable alternate screen buffer
		return "\027[?1049l"
	end
end

-- read a key with optional timeout
function term:read_key(timeout)
	local function get_char_timeout()
		return getch.get_char_cooked(timeout)
	end
	local resolved_key, seq = getch.get_key_mbs(get_char_timeout, getch.key_table)
	if (not resolved_key) and (#seq==1) then
		local c = string.char(seq[1])
		return resolved_key, seq, c, c
	else
		return resolved_key, seq, nil, resolved_key
	end
end

-- read a line of text input
function term:read_line()
	local line = ""
	repeat
		local key,seq,char = self:read_key()
		if key == "backspace" then
			line = line:sub(1, -2)
			self.write("\008 \008")
		elseif char then
			line = line .. char
			self.write(char)
		end
		self.flush()
	until key == "enter"
	return line
end

-- automatically get the terminal size on load
term:get_term_size()

return term
