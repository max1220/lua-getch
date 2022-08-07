-- Utillities for managing the scoreboard
-- This implements loading a list of scores from a file,
-- adding a single scoreboard entry, and storing the list in a file.
local scores = {}

-- ranking of difficulties
local difficulties = {
	hard = 1,
	medium = 2,
	easy = 3,
	custom = 4
}

-- add a highscore to the list of highscores
function scores:add(score, name, difficulty)
	-- insert the scoreboard entry
	local entry = {
		score = score,
		name = name,
		time = os.time(),
		difficulty = difficulty
	}
	table.insert(self, entry)

	-- sort the scoreboard
	table.sort(self, function(a,b)
		if a.difficulty == b.difficulty then
			if a.score == b.score then
				return a.time>b.time
			end
			return a.score>b.score
		end
		return difficulties[a.difficulty]<difficulties[b.difficulty]
	end)

	-- get the position of the added entry
	for k,v in ipairs(self) do
		if v == entry then
			return k
		end
	end
end

-- load highscores list from disk
function scores:load_from_file(filename)
	-- try to open scoreboard file
	local highscores_file = io.open(filename)
	if not highscores_file then
		return
	end

	-- remove old entries
	for i=1, #self do
		self[i] = nil
	end

	-- add entries from file
	for line in highscores_file:lines() do
		local score, name, time, difficulty = line:match("^(%d+)%s+(%S+)%s+(%d+)%s+(%S+)$")
		if tonumber(score) then
			table.insert(self, {
				score = tonumber(score),
				name = name,
				time = tonumber(time),
				difficulty = difficulty
			})
		end
	end

	highscores_file:close()
end

-- store sorted list of highscores on disk
function scores:save_to_file(filename)
	local file = io.open(filename, "w")
	if not file then
		return
	end
	for _,entry in ipairs(self) do
		file:write(("%s %s %d %s\n"):format(entry.score, entry.name, entry.time, entry.difficulty))
	end
	file:close()
end

return scores
