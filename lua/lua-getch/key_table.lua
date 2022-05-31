-- a default key table, that resolves most common terminal escape codes.
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
