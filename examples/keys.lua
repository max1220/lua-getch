local ret = {}

ret.keys = {
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

ret.keys_2 = {
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
		},
		[51] = {
			[126] = "delete"
		}
	},
	[10] = "alt-enter"
}


function ret.getKey(this, table, getKeyFunction)
	local ckey = getKeyFunction()
	if type(table[ckey]) == "string" then
		return table[ckey]
	elseif type(table[ckey]) == "table" then
		return this(this, table[ckey], getKeyFunction)
	else
		return ckey
	end
end

return ret
