--[[
this file produces the actual module for lua-getch, combining the
C functionallity with the lua functionallity. You can use the C module
directly by requiring getch directly.
--]]

local getch = require("lua-getch.getch")

getch.get_key_mbs = require("lua-getch.get_key_mbs")

return getch
