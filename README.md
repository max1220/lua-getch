lua-getch
=========

Description
-----------
Provides a getch function for Lua that allows getting Keyboard codes unbuffered, optionally non-blocking.
This allows, for example, the creation of Terminal GUI's.

Has utillity function for looking up key codes.
This approximates ncurses' `keypad(win, TRUE)` mode but without requiring a dependency on
ncurses.



Dependencies
------------
To build this Module you need:
 * Lua 5.1 + headers

Install in Debian/Ubuntu:

    sudo apt-get install lua5.1 liblua5.1-0-dev gcc make



Build
-----

    make

The build module is getch.so. Install by putting it somewhere in Lua's package.cpath:

    lua -e "print(package.path:gsub(';', '\n'):gsub('?', '[?]'))"



Examples
--------

    #!/usr/bin/lua
    local getch = require("lua-getch")
    while true do
      print(getch.blocking())
    end

(Prints the keycodes of pressed keys.)

Examples are in the examples/ folder.



Usage
-----
Load the module like this:

    local getch = require("lua-getch")

The module exports 2 functions:
* blocking():
  + Gets the next input byte, blocking(wait for key)
* non_blocking():
  + Gets the next input byte, non-blocking(check for key)
* get_key_mbs(getch, key_table)
  + Gets the next resolved key from the key_table or key (using the getch callback function).
