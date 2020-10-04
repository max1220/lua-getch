# lua-getch

Provides a getch function for Lua that allows getting Keyboard codes unbuffered, optionally non-blocking.
This allows, for example, the creation of Terminal GUI's.

Provides utillity function for decoding multi-byte sequences.
This approximates ncurses' `keypad(win, TRUE)` mode but without requiring a dependency on ncurses.



# Dependencies

To build this Module you need:

 * Lua 5.1 + headers

Install in Debian/Ubuntu:

    sudo apt-get install lua5.1 liblua5.1-0-dev gcc make



# Build

    make

The build module is getch.so. Install by running

	make install

This will install the C module `getch.so` to `/usr/local/lib/lua/5.1/`, and
the Lua module from `lua/` to `/usr/local/share/lua/5.1/lua-getch/`.


# Example 'simple.lua'

	-- simple.lua, print the character code as a number
    #!/usr/bin/lua
	local getch = require("lua-getch")
	while true do
		print(getch.blocking())
	end



# Example 'resolve.lua'

	-- resolve.lua, print a resolved character code
	#!/usr/bin/lua
	local getch = require("lua-getch")
	local key_table = { -- resolve arrow keys on most terminals
		[27] = { [91] = { [65] = "up", [66] = "down", [67] = "right", [68] = "left" } }
	}
	while true do
		local key_code, key_resolved = getch.get_mbs(getch.blocking, key_table)
		if key_resolved then
			print("Arrow key pressed:", key_resolved)
		else
			print("Other key pressed:", key_code)
		end
	end

More examples are in the `examples/` folder.



# Usage

To load the module, use `getch = require("lua-getch")`. This will load the C library and the Lua support library.

You can also only load the C module using `require("getch")`. `getch.get_mbs` will not be available.

You can also only load the `getch.get_mbs` function using require("lua-getch.get_mbs"). It has no dependency on the C module.



## `ch = getch.blocking()`

Gets a single character, blocking(waits for a character). `ch` is a character code as defined by the terminal,
and is returned as a number.
Note that a character code might be part of an escape sequence send by the terminal.



## `ch = getch.non_blocking()`

Gets a single character, non-blocking(check for a character).
Returns nil if no character is available, the character code otherwise(see above).



## `ch, resolved = getch.get_mbs(callback, key_table)`

Utility function to help decode multibyte terminal sequences, by looking up
successive character codes provided by `callback` in the nested `key_table`.
This function calls the `key = callback()` function to get an index into the `key_table`.
If the returned key is a function, that function is called with the callback and the last key as arguments,
and the return value is used as the new value for key(e.g. `key = key(callback, last_key)`).
If that key is present in the key_table and it's corresponding table entry is not a table value,
it is returned as-is(`return key_table[key]`). If it is a table value this function calls itself in a
recursive manner to resolve the multibyte sequence(e.g. `return get_mbs(callback, key_table[key])`).

e.g. when you press the up arrow key on most terminals, a sequence such as `\e[A` (decimal 27, 91, 65)
is generated, so you can use this function to look up this sequence in a table that could like this:

```
local key_table = { [27] = { [91] = { [65] = "Up" } } }
local ch, resolved = getch.get_mbs(getch.blocking, key_table)`
```

In this example, the function would return `65, "Up"`.

There would be 3 calls to getch.get_mbs:
```
local ch, resolved = getch.get_mbs(getch.blocking, { [27] = { [91] = { [65] = "Up" } } }) -- calls in return...
getch.get_mbs(getch.blocking, { [91] = { [65] = "Up" } }) -- calls in return...
getch.get_mbs(getch.blocking, { [65] = "Up" }) -- returns 65, "Up"
```

*Note*: `ch` is always the *last* return value from callback.



# TODO

 * Implement an optional FFI version for LuaJIT
