lua-getch
=========

Description
-----------
Provides a getch function for Lua that allows getting Keyboard codes unbuffered, optionally non-blocking.
This allows, for example, the creation of Terminal GUI's.

Has built in support for determining whether a key press was the Escape key, or an escape code such as an 
arrows key. This approximates ncurses' `keypad(win, TRUE)` mode but without requiring a dependency on
ncurses. This functionality is only available in the `blocking` call.

Dependencies
------------
To build this Module you need:
 * Lua 5.1 + headers

Install in Debian/Ubuntu:

    sudo apt-get install lua5.1 liblua5.1-0-dev gcc



Build
-----

    make

The build module is getch.so. Install by putting it somewhere in Lua's package.cpath:

    lua -e "print(package.path:gsub(';', '\n'):gsub('?', '[?]'))"




Examples
--------
Examples are in the examples/ folder.



Usage
-----
The module exports 2 functions:
* getch():
  + Gets the next input byte, blocking
* getch_non_blocking():
  + Gets the next input byte, non-blocking

Example:

    #!/usr/bin/lua
    local getkey = require("getkey")
    while true do
      print(string.byte(getkey.getkey()))
    end

(Prints the keycodes of pressed keys.)
