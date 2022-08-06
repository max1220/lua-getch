local scene_utils = require("scene_utils")
local scores = require("scoreboard")
local term = require("terminal")

-- The highscore scene.
-- Displays the score at the point the game ended,
-- and asks for a name.

local scene = {}
scene.highscore_filename = "scoreboard.txt"



-- remember the game passed in if any
function scene:on_enter(game)
	self.game = game

	-- load the scoreboard from a file
	scores:load_from_file(self.highscore_filename)

	-- calculate highscore position
	self.highscore_x, self.highscore_y = term:get_center_rect_position(63,12)

	-- always re-confirm name when showing the highscore
	scene.name_asked = false
end

-- when not submitted already,
-- submit the game to the leaderboard,
-- get the leaderboard position
function scene:submit_highscore()
	-- get the difficulty as a string
	local difficulty_str = "custom"
	local d = self.game.difficulty_factor
	local m = self.game.max_points_on_board
	if (self.game.width ~= 10) or (self.game.height ~= 10) then
		-- irregular dimensions, so also custom
		difficulty_str = "custom"
	elseif (d == 0.2) and (m==3) then
		difficulty_str = "easy"
	elseif d == 0.5 and (m==2) then
		difficulty_str = "medium"
	elseif d == 0.8 and (m==2) then
		difficulty_str = "hard"
	end

	if self.name and (not self.game.highscore_pos) then
		self.game.highscore_pos = scores:add(self.game.score, self.name, tostring(self.game.difficulty_factor))
		scores:save_to_file(self.highscore_filename)
	end
end

-- ask the player for a name
function scene:ask_for_name()
	if (not self.game) or (self.game.highscore_pos) or (self.name_asked) then
		-- don't ask the user for a name if not submitting a game to highscore
		return
	end

	-- draw the highscore UI
	term.write(term:esc_pos(1,1))
	term.write(term.esc_reset_sgr)
	term.write(term.esc_clear)

	-- show message asking the user for a name
	print("Please enter your name for the highscore: ")
	if self.name then
		print("(leave blank to use " .. self.name ..")")
	else
		print("(leave blank to not submit to highscore)")
	end
	term.flush()

	-- read a complete line of input
	local name = term:read_line()
	if name == "" then
		-- no name specified, use old name or no name
		self.name_asked = true
	elseif name then
		-- name specified, use name
		self.name_asked = true
		self.name = name
	end

	return self.name or true
end

scene.you_lost_text = {
	"  #   #   ###   #   #     #       ###   #####  #####  #",
	"  # #   #   #  #   #     #      #   #  #        #    # ",
	"  #    #   #  #   #     #      #   #  #####    #    #  ",
	" #    #   #  #   #     #      #   #      #    #        ",
	"#     ###    ###      #####   ###   #####    #    #    "
}

-- show the title of the highscore screen
function scene:output_highscore_title()
	-- show the text at the top of the leaderboard
	-- (the current player, score, length, leaderboard position)
	local text_top =
		("Name: %s | Leaderboard: %s | Score: %s | Length: %s"):format(
			self.name or "-",
			tostring(self.game.highscore_pos or "-"),
			tostring(self.game and self.game.score or "-"),
			tostring(self.game.snake_len and self.game.snake_len or "-")
		)
	local center_x = term:get_center_rect_position(#text_top)
	term:print_at(center_x,self.highscore_y-2, text_top)

	if self.game then
		center_x = term:get_center_rect_position(#self.you_lost_text[1])
		if (self.highscore_y-(3+#self.you_lost_text)) >= 0 then
			term:print_lines_at(center_x, 2, self.you_lost_text)
		end
	end

	-- show the text at the bottom of the leaderboard
	local text_bottom = "Press enter to restart. Press escape/q to quit"
	center_x = term:get_center_rect_position(#text_bottom)
	term:print_at(center_x,self.highscore_y+13, text_bottom)
end

-- print the top n entries from the list oh highscores, optionally "highlight" an entry
-- width is 63 characters, height is 12 lines
function scene:output_highscores_top_n(n, highlight)
	local ox, oy = self.highscore_x, self.highscore_y
	term.write(term:esc_pos(ox,oy))
	term.write(" Place | Score    | Name                 | Date                \n")
	term.write(term:esc_pos(ox,oy+1))
	term.write("-------+----------+----------------------+---------------------\n")
	for i=1, n do
		term.write(term:esc_pos(ox,oy+1+i))
		local entry = scores[i]
		local place_str = ("%3d"):format(i)
		place_str = place_str .. ((i==1) and "st" or ((i==2) and "nd") or "th")
		term.write((i==highlight) and ">" or " ")
		if entry then
			local time_str = os.date("%d-%m-%Y %H:%M:%S", entry.time)
			term.write(("%s | %8d | %20s | %s\n"):format(place_str, entry.score, entry.name, time_str))
		else
			term.write(("%s | \n"):format(place_str))
		end
	end
end

-- handle input for the scene
function scene:input()
	-- wait for key
	local _,_,_,combined = term:read_key(1)
	if combined == "enter" then
		scene_utils:change_scene("scene_snake")
	elseif combined == "m" then
		scene_utils:change_scene("scene_title")
	elseif (combined == "q") or (combined == "escape") then
		scene_utils:change_scene()
	end
end

-- draw the highscore UI
function scene:output()
	term.write(term:esc_pos(1,1))
	term.write(term.esc_reset_sgr)
	term.write(term.esc_clear)

	--  update terminal output
	self:output_highscore_title()
	term.flush()


	self:output_highscores_top_n(10, self.game and self.game.highscore_pos)
	term.flush()
end

-- main scene callback function
function scene:on_update()
	-- ask for name, if needed
	if self:ask_for_name() then
		return
	end

	-- submit highscore if not done already
	self:submit_highscore()

	self:output()
	self:input()
end



return scene
