lua-getkey
==========

Description
-----------
Provides a getkey function for Lua that allows getting Keyboard codes unbuffered.
This allows, for example, the creation of Terminal GUI's.



Dependencies
------------
To build this Module you need:
 * Lua 5.1 + headers

Install in Debian/Ubuntu:

    sudo apt-get install lua5.1 liblua5.1-0-dev



Build
-----
The build process is straight-forward:

    cd getkey
    ./make.sh

The build module is in getkey/getkey.so.



Test
----
For a quick test run example/example1.lua.
It should print the byte values of inputed keys.



Usage
-----
The module exports 1 function:
* getkey():
  + Gets the next input byte.

Please note that in order to get the full keycode you need to call this function multiple times, since Keycodes are multi-byte!

Example:

    #!/usr/bin/lua
    local getkey = require("getkey")
    while true do
      print(string.byte(getkey.getkey()))
    end

(Prints the keycodes of pressed keys.)

__For more examples, please have a look at the examples/ directory!__

Please note that in order to make Lua find the module, you need to copy it to Lua's default search path,
To list the folders Lua looks for Modules, please use:

    lua -e "print(package.path:gsub(';', '\n'):gsub('?', '[?]'))"

Where [?] is the module's filename.
