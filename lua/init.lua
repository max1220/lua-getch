--[[
this file produces the actual module for lua-getch, combining the
C functionallity with the lua functionallity. You can use the C module
directly by requiring getch directly.
--]]


-- load C module
local getch = require("getch")

-- append to the returned table
getch.get_mbs = require("lua-getch.get_mbs")

-- return the combined module
return getch
