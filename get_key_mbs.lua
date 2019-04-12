-- this library is used to get a key from stdin, resolving multi-byte
-- sequences automaticall





-- multibyte sequences are resolved by using this table.
-- each (sub-)table maps a single byte to either a return value,
-- or to another table that resolves the next character code.
local default_key_table = {
	[10] = "enter",
	[27] = {
		[91] = {
			[65] = "up",
			[66] = "down",
			[67] = "right",
			[68] = "left"
		}
	}
}

-- get a key, and resolve defined multibyte sequences. (recursive)
local function get_key_mbs(get_ch, key_table, i)
	local key_table = key_table or default_key_table
	local i = i or 1
	local key_code = get_ch()
	local key_resolved = key_table[key_code]
	if type(key_resolved) == "table" then
		-- we're in a multibyte sequence, get more characters recursively(with maximum limit)
		if i < 10 then
			return get_key(get_ch, key_resolved, i+1)
		end
	elseif key_resolved then
		-- we resolved a multibyte sequence
		return key_code, key_resolved
	else
		-- Not in a multibyte sequence
		return key_code
	end
end

return get_key_mbs
