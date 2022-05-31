# lua-getch

Provides a getch function for Lua that allows getting Keyboard codes
unbuffered, optionally non-blocking from stdin.

This allows, for example, the creation of Terminal GUI's.

Provides utility function for decoding multi-byte sequences.
This approximates ncurses' `keypad(win, TRUE)` mode but without requiring a dependency on ncurses.



# Dependencies

To build this Module you need:

 * Lua + headers

Install in Debian/Ubuntu:

    sudo apt-get install lua5.1 liblua5.1-0-dev gcc make



# Build

By default, the modules builds for Lua5.1. To start the build, just run:

    make

The build module is getch.so. Install by running

	sudo make install

This will install the C module `getch.so` to `/usr/local/lib/lua/5.1/`, and
the Lua module from `lua/` to `/usr/local/share/lua/5.1/lua-getch/`.

You can compile and install for another version by specifying parameters make:

    make clean
    make LUA_INCDIR=/usr/include/lua5.3 LUA_LIBS=-llua5.1 all
    sudo make INSTALL_PATH=/usr/local/share/lua/5.3 INSTALL_CPATH=/usr/local/lib/lua/5.3 install



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



# TODO

 * Implement an optional FFI version for LuaJIT
