-- Implementation of the state and logic of the snake game
-- This handles changing the snake head direction, resetting the board,
-- and iterating the game board to the next state(update the board)
local game = {}

-- reset game to initial state
function game:reset(board_w,board_h, max_points_on_board, difficulty_factor)
	-- check arguments
	self.board_w = assert(tonumber(board_w) or self.board_w)
	self.board_h = assert(tonumber(board_h) or self.board_h)
	self.max_points_on_board = assert(tonumber(max_points_on_board) or self.max_points_on_board)
	self.difficulty_factor = assert(tonumber(difficulty_factor) or self.difficulty_factor)

	-- initialize the board to 0
	self.board = {}
	for y=1, self.board_h do
		self.board[y] = {}
		for x=1, self.board_w do
			self.board[y][x] = 0
		end
	end


	-- set to true if game has ended(gameover)
	self.gameover = false

	-- current length of the snake
	self.snake_len = 2

	-- current difficulty
	self.difficulty = 1

	-- current score
	self.score = 0

	-- head position(front of snake)
	self.head_x = math.floor(self.board_w/2)
	self.head_y = math.floor(self.board_h/2)

	-- head direction(initially moving to screen right)
	self.head_dx = 1
	self.head_dy = 0

	-- position of the game in the highscore(only set when submitted to highscore)
	self.highscore_pos = nil

	-- add initial snake "body pieces" to the board, to the left of the head.
	for x=0, self.snake_len-1 do
		self.board[self.head_y][self.head_x-x] = x+1
	end

end

-- perform a single iteration of the game update
function game:update()
	-- only update the game state if game is supposed to run
	if self.gameover then
		return
	end

	-- iterate over the complete board,
	-- check if there are points on it,
	-- and check if there is still free space on it.
	local points_on_board = 0
	local is_full = true

	for y=1, self.board_h do
		for x=1, self.board_w do
			local id = self.board[y][x]
			if id >= self.snake_len then
				self.board[y][x] = 0
			elseif id > 0 then
				self.board[y][x] = id + 1
			elseif id < 0 then
				points_on_board = points_on_board + 1
			elseif id == 0 then
				is_full = false
			end
		end
	end

	-- end the game if there are no more free tiles
	if is_full then
		self.gameover = true
		return true
	end

	-- spawn points on empty tiles if needed
	while (points_on_board<self.max_points_on_board) and ((points_on_board==0) or (math.random(1, 25)==1)) do
		local x,y = math.random(1, self.board_w), math.random(1,self.board_h)
		if self.board[y][x] == 0 then
			self.board[y][x] = -math.random(1,3)
			points_on_board = points_on_board + 1
		end
	end

	-- move the snake head
	self.head_x = self.head_x + self.head_dx
	self.head_y = self.head_y + self.head_dy

	-- wrap the snake around the board
	if self.head_x > self.board_w then
		self.head_x = 1
	elseif self.head_x < 1 then
		self.head_x = self.board_w
	end
	if self.head_y > self.board_h then
		self.head_y = 1
	elseif self.head_y < 1 then
		self.head_y = self.board_h
	end

	-- check what tile is at the new head of the snake
	local id = self.board[self.head_y][self.head_x]


	if id<0 then
		-- snake head is at a bonus point,
		-- increase snake length by 1
		self.snake_len = self.snake_len + 1

		-- increase diffuculty by absolute value of id
		self.difficulty = self.difficulty + math.abs(id)

		-- add some points to the score
		self.score = self.score + math.abs(id)*10
	elseif id>0 then
		-- snake collided with itself
		self.gameover = true
	end

	-- add the new head tile to the board
	self.board[self.head_y][self.head_x] = 1
end

-- set a new direction of the snake head
function game:set_head_direction(head_direction)
	if (head_direction == "up") and (self.head_dy == 0) then
		self.head_dx = 0
		self.head_dy = -1
	elseif (head_direction == "down") and (self.head_dy == 0) then
		self.head_dx = 0
		self.head_dy = 1
	elseif (head_direction == "left") and (self.head_dx == 0) then
		self.head_dx = -1
		self.head_dy = 0
	elseif (head_direction == "right") and (self.head_dx == 0) then
		self.head_dx = 1
		self.head_dy = 0
	else
		return false
	end
	return true
end

return game
