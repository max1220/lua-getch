#!/usr/bin/env lua5.1
-- This is a simple snake game.
-- Implemented using only the lua-getch library, and basic terminal I/O.
local term = require("terminal")
local scene_utils = require("scene_utils")



-- disable output buffering
io.stdout:setvbuf("full")

-- enable alternate screenbuffer
term.write(term:esc_alternate_screenbuffer(true))

-- start application loop for title screen
scene_utils:run_scene_updates("scene_title")
-- (application terminated)


-- disable alternate screenbuffer
term.write(term.esc_reset_sgr)
term.write(term:esc_alternate_screenbuffer(false))

-- terminate application
print("bye!")
os.exit()



