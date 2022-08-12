--[[
this file produces the actual module for lua-getch, combining the
C functionality with the Lua functionality. You can use the C module
directly by requiring getch directly.
--]]

-- load C module
local getch = require("getch")
local bit = require("bit32")




-- enter non-canonical mode and disable echo("raw mode")
local lflags, restore_fd, is_nb
function getch.set_raw_mode(fd, non_blocking)
	if lflags then
		-- already in raw mode
		return
	end

	-- store previous terminal attributes
	local _, _, _, old_lflags = getch.get_termios_attributes(fd)
	lflags = old_lflags
	restore_fd = fd

	-- remove ICANON and ECHO from lflags
	local new_lflags = bit.band(old_lflags, bit.bnot(getch.lflags.ICANON + getch.lflags.ECHO))

	-- set the new flags
	assert(getch.set_termios_attributes(fd, nil, nil, nil, new_lflags))

	-- enable non-blocking mode if requested
	if non_blocking then
		is_nb = non_blocking
		getch.set_nonblocking(fd, true)
	end

	-- indicate success
	return true
end

-- restore the terminal attributes after entering raw mode
function getch.restore_mode()
	if not restore_fd then
		-- already restored
		return
	end

	-- restore previous terminal attributes
	assert(getch.set_termios_attributes(restore_fd, nil, nil, nil, lflags))
	lflags = nil

	-- disable non-blocking mode if it was enabled
	if is_nb then
		getch.set_nonblocking(restore_fd, true)
	end

	-- indicate success
	return true
end

-- read a single character
function getch.get_char(fd)
	-- read a single character from stdin
	local char = fd:read(1)
	if char then
		-- return the character that was read as a byte
		return char:byte()
	end
end

-- read a single character from stdin
function getch.get_char_stdin()
	return getch.get_char(io.stdin)
end

-- disable buffering, enter raw mode and, get a char, then restore terminal
function getch.get_char_cooked(timeout)
	-- disable buffering through libc
	io.stdin:setvbuf("no")

	-- set raw(non-linebuffered) mode, disable automatic echo of characters
	getch.set_raw_mode(io.stdin)

	-- restore original mode
	local function restore()
		-- leave raw mode
		getch.restore_mode()

		-- set line buffering
		io.stdin:setvbuf("line")
	end

	-- optionally wait up to timeout seconds for stdin to become ready.
	-- If timeout is reached, nil is returned.
	if timeout then
		local ok, stdin_ready = getch.select(timeout, io.stdin)
		if ok and (not stdin_ready) then
			restore()
			return
		end
	end

	-- get the character
	local char = getch.get_char_stdin()

	restore()

	return char
end

-- recursively try to resolve a multibyte sequence by calling get_key
-- repeatedly, and resolving results using the key_table.
-- get_key is a callback that is called when a new key in the multibyte
-- sequence is requested, key_table is the table that is used to resolve
-- the sequence. Remaining arguments are for recursion.
-- The first return value is a resolved (multibyte) sequence
-- from the key_table, or nil if aborted.
-- The second return value is always returned and contains every
-- key that was read.
function getch.get_key_mbs(get_key, key_table, max_depth, seq)
	-- maximum length of the escape sequence
	max_depth = max_depth or 32

	-- the sequence of keys already in this sequence
	seq = seq or {}

	-- get a keycode
	local key_code = get_key()

	-- append to sequence
	table.insert(seq, key_code)

	-- return if max_depth is reached
	if #seq>=max_depth then
		return nil, seq
	end

	-- try to resolve the key
	local key_resolved = key_table[key_code]

	-- try to resolve the key based on it's type
	while key_resolved do
		if (type(key_resolved) == "table") and (not key_resolved.__final) then
			-- key not resolved yet, recursively try to resolve the next key by
			-- looking it up in a table(key_resolved is the table).
			return getch.get_key_mbs(get_key, key_resolved, max_depth, seq)
		elseif type(key_resolved) == "function" then
			-- key not resolved, try to look it up using a function
			key_resolved = key_resolved(get_key, key_code, seq)
		else
			-- return the resolved key and the sequence that caused it.
			return key_resolved, seq
		end
	end

	-- no key was resolved, return the sequence
	return nil, seq
end





-- include a simple key_table for decoding some input escape sequences
getch.key_table = require("lua-getch.key_table")

-- return the combined module
return getch
