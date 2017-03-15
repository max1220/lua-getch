lua-getch
=========

Description
-----------
Provides a getch function for Lua that allows getting Keyboard codes unbuffered, optionally non-blocking.
This allows, for example, the creation of Terminal GUI's.



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

Please note that in order to get the full keycode you need to call this function multiple times, since Keycodes are multi-byte!

Example:

    #!/usr/bin/lua
    local getkey = require("getkey")
    while true do
      print(string.byte(getkey.getkey()))
    end

(Prints the keycodes of pressed keys.)
