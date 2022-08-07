local term = require("terminal")
local game = require("snake_logic")
local scene_utils = require("scene_utils")

-- Main game scene.
-- This renders the current state of the board, and handles the input
-- for the game

local scene = {}

-- check inputs
function scene:input()
	-- calculate how long to wait for input from the player,
	-- based on current difficulty
	local delay = 1/(self.game.difficulty^self.game.difficulty_factor)

	-- wait for a key
	local _,_,_,combined = term:read_key(delay)

	if (combined=="up") or (combined=="down") or (combined=="left") or (combined=="right") then
		-- arrow keys(change snake head direction)
		self.game:set_head_direction(combined)
	elseif (combined=="r") or (combined=="enter") then
		-- reset the game
		self.game:reset()
	elseif (combined=="q") or (combined=="escape") then
		-- exit the game
		scene_utils:change_scene()
	--elseif (combined=="p") then
		-- pause game(currently unimplemented)
	elseif (combined=="d") then
		-- toggle debug view
		self.debug = not self.debug
	else
		return false
	end

	return true
end

-- output the top header to the screen
function scene:output_header(oy)
	local top_line = ("Snake!  |  Score: %5d  |  Length: %3d\n"):format(self.game.score, self.game.snake_len)
	local center_x = term:get_center_rect_position(#top_line, 1)
	term:print_at(center_x, oy, top_line)
end

-- output the game board to the screen
function scene:output_board(ox,oy, border_color_bg, border_color_fg)
	-- draw top border if needed
	if border_color_bg then
		term.write(term:esc_pos(ox, oy))
		term.write(term:esc_color_16(border_color_bg))
		term.write(term:esc_color_16(border_color_fg, nil, true))
		term.write("+"..("-"):rep(self.game.board_w*self.cell_w).."+")
	end

	-- for every terminal output row for the board...
	for ty=1, self.game.board_h*self.cell_h do
		-- set cursor to beginning of line
		term.write(term:esc_pos(ox, ty+oy-((border_color_fg and 0) or 1)))

		-- draw left border if needed
		if border_color_bg then
			term.write(term:esc_color_16(border_color_bg))
			term.write(term:esc_color_16(border_color_fg, nil, true))
			term.write("|")
		end

		-- for every terminal output column for the board...
		for tx=1, self.game.board_w*self.cell_w do

			-- get cell position
			local x = math.floor((tx-1) / self.cell_w)+1
			local y = math.floor((ty-1) / self.cell_h)+1

			-- get id of the current cell on the board
			local cell = self.game.board[y][x]

			-- determine cell color
			local color, bright
			if cell == 0 then
				-- empty cell
				color = "black"
			elseif cell == 1 then
				-- snake head
				color = "green"
				bright = true
			elseif cell > 0 then
				-- snake body
				color = "green"
			elseif cell < 0 then
				-- bonus point
				color = "bright cyan"
			end

			if (self.cell_w==1) or (tx%self.cell_w == 1) then
				-- beginning of cell in line, output set color sequence
				term.write(term:esc_color_16(color, bright))
			end

			-- write cell character
			term.write(" ")

			if (self.cell_w~=1) and (tx%self.cell_w == 0) then
				-- end of cell in line, reset color
				term.write(term.esc_reset_sgr)
			end
		end

		-- draw right border if needed
		if border_color_bg then
			term.write(term:esc_color_16(border_color_bg))
			term.write(term:esc_color_16(border_color_fg, nil, true))
			term.write("|")
		end
		term.flush()
	end

	-- draw bottom border if needed
	if border_color_bg then
		term.write(term:esc_pos(ox, self.game.board_h*self.cell_h+oy+1))
		term.write(term:esc_color_16(border_color_bg))
		term.write(term:esc_color_16(border_color_fg, nil, true))
		term.write("+"..("-"):rep(self.game.board_w*self.cell_w).."+")
	end
end

-- update complete output
function scene:output()
	-- clear the screen
	term.write(term.esc_reset_sgr)
	term.write(term.esc_clear)

	-- draw the top bar
	self:output_header(1)
	term.flush()

	-- draw the game board
	local border_colors = {"yellow", "blue", "magenta", "cyan", "red", "green"}
	local current_border_i = 1+(math.floor(self.game.snake_len/4)%#border_colors)
	local current_border_color = border_colors[current_border_i]
	self:output_board(self.board_x,self.board_y, current_border_color, current_border_color)

	-- set the cursor
	term.write(term.esc_pos(1,1))
	term.flush()
end

-- main update function
function scene:on_update()
	-- draw the game
	self:output()

	-- check input
	self:input()

	-- update the game state
	self.game:update()

	-- check if the game is over
	if self.game.gameover then
		scene_utils:change_scene("scene_scoreboard", self.game)
	end
end

-- get the centered position and largest possible cell size
-- for the current terminal size
function scene:get_board_position_cell_size()
	-- determine largest cell size for this terminal size
	local term_w, term_h = term.cols, term.rows
	local max_cell_w = math.floor(term_w/self.game.board_w)
	local max_cell_h = math.floor(term_h/self.game.board_h)

	-- board doesn't fit on screen
	if (max_cell_w<=0) or (max_cell_h<=0) then
		return
	end

	local cell_size = math.min(max_cell_w, max_cell_h)
	local cell_w, cell_h = cell_size, cell_size
	if cell_size >= 3 then
		cell_h = math.floor(0.75*cell_size)
	end

	-- calculate board size
	local board_w = 2+cell_w*self.game.board_w
	local board_h = 2+cell_h*self.game.board_h

	-- center board on terminal
	local board_center_x, board_center_y = term:get_center_rect_position(board_w, board_h)

	return board_center_x, board_center_y+1, cell_w, cell_h
end

-- called when the scene is (re-)loaded
function scene:on_enter(...)
	self.game = game

	self.game:reset(...)

	-- calculate board position and cell size
	self.board_x, self.board_y, self.cell_w, self.cell_h = self:get_board_position_cell_size()
	assert(self.cell_w)

	term.write(term.esc_clear)
	term.write(term.esc_pos())
end

return scene

