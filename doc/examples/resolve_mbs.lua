#!/usr/bin/env lua5.1
local getch = require("lua-getch")

print("Entering Multi-byte sequence decoding example(read special terminal sequences from stdin).")

print("Press q to quit.")
local run = true
while run do
	-- try to get a key, automatically resolve multi-byte sequences
	local resolved, seq = getch.get_key_mbs(getch.get_char_cooked, getch.key_table)

	-- multi-byte sequence detected
	if resolved then
		print("resolved:", resolved)
	end

	-- seq contains every key that was detected, in sequence or not
	print("key sequence:", #seq)
	for _,v in ipairs(seq) do
		print("  key:", v)

		-- quit on q key
		if string.char(v) == "q" then
			run = false
		end
	end
end

print("bye!")
