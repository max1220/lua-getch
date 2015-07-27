#!/usr/bin/lua
local getkey = require("getkey")
-- Note: You need to have copied the keykey function somewhere in the path for this to work!


local keys = {
	[27] = {
		[91] = {
			[65] = "up",
			[66] = "down",
			[68] = "left",
			[67] = "right",
			[53] = {
				[126] = "page_up"
			},
			[54] = {
				[126] = "page_down"
			},
			[49] = {
				[59] = {
					[51] = {
						[67] = "alt-right",
						[68] = "alt-left"
					}
				},
				[126] = "pos1"
			},
			[52] = {
				[126] = "end"
			}
		},
		[10] = "alt-enter"
	}
}



function getkeyWrapper(this, table, getKeyFunction)
  -- Arguments:
  -- this: the function it self, needed for recursion
  -- table: Key mapping table
  -- getKeyFunction: Function to get the next key byte.
	local ckey = getKeyFunction()
	if type(table[ckey]) == "string" then
		return table[ckey]
	elseif type(table[ckey]) == "table" then
		return this(this, table[ckey], getKeyFunction)
	else
		return ckey
	end
end




while true do
  local cKey = getkeyWrapper(getkeyWrapper, keys, getkey.getkey)
  if type(cKey) == "number" then
    print(string.format("Char:\t%d (%s)", cKey, string.char(cKey)))
  elseif type(cKey) == "string" then
    print("Key:", cKey)
  end
end
