# lua-getch

This library contains some C functions and Lua functions for handling
terminal user input.

Specifically, it provides function for changing terminal parameters
to enable raw, non-blocking input using the C functions from termios and
fctnl.

It also contains some utillity functions for working with the terminal,
such as decoding the multi-byte sequences generated by terminals on
some keypresses, among other things(this approximates ncurses
`keypad(win, TRUE)` mode, but without requiring a dependency on ncurses).





# Installation

See [doc/INSTALLATION.md](doc/INSTALLATION.md)

This library is packaged and build using Luarocks, which makes building
and installing easy.

You can download a release from the official luarocks.org repository using:

```
luarocks install lua-getch
# alternatively:
luarocks install --server=https://luarocks.org/manifests/max1220 lua-getch
```

You can run this command as root to install system-wide.

Or you can build a version from the Git repository:

```
git clone https://github.com/max1220/lua-getch
cd lua-getch
# install locally, usually to ~/.luarocks
luarocks make --local
```

When installing locally, or as non-root user you need to tell Lua where to
look for modules installed using Luarocks using the LUA_PATH environmente variable.
Luarocks can generate this variable:

```
luarocks path >> ~/.bashrc
```




# Usage

There is detailed usage information in the documentation([doc/USAGE.md](doc/USAGE.md)).

There are some examples, including a simple snake game in [doc/examples](doc/examples).

A basic usage example:

```
#!/usr/bin/lua
local getch = require("lua-getch")
while true do
	local resolved, seq = getch.get_key_mbs(getch.get_char_cooked, getch.key_table)
	if resolved then
		print("special key:", resolved)
	else
		for k,v in ipairs(seq) do
			print("character", v)
		end
	end
end
```





# Intended use

This library is written by me, max1220, for the sole purpose of having
fun with Lua, learning, and enabling me to create more complex projects.

No gurantees, of any kind(functionallity, long-term stabillity,
long-term maintenance etc.).

That beeing said, this library is quite simple, and somewhat tested.
