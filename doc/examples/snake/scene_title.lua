local term = require("terminal")
local scene_utils = require("scene_utils")

-- Title screen scene.
-- This displays the title screen(snake logo, instructions), and allows
-- the player to start a game.
local scene = {}

scene.title_text = {
	"                                            ",
	"      #####  #   #  #####  #   #  #####  #  ",
	"     #      ##  #  #   #  #  #   #      #   ",
	"    #####  # # #  #####  ###    #####  #    ",
	"       #  #  ##  #   #  #  #   #            ",
	"  #####  #   #  #   #  #   #  #####  #      ",
	"",
	"    A snake-game written as an example of",
	"    what to do with the lua-getch library.",
	"",
	"Game keys:",
	" up/down/left/right - change snake direction",
	" enter - reset game",
	" q/escape - quit",
	"",
	"Please select difficulty:",
	""
}

function scene:input()
	local center_x = term:get_center_rect_position(#self.title_text[1])

	-- read a key from the user
	local _,_,_, combined = term:read_key(1)
	if (combined == "escape") or (combined == "q") then
		-- terminate the application cleanly
		scene_utils:change_scene()
	elseif (combined == "enter") then
		-- change to game scene
		if self.selected == 1 then
			scene_utils:change_scene("scene_snake", 10,10, 3, 0.2)
		elseif self.selected == 2 then
			scene_utils:change_scene("scene_snake", 10,10, 2, 0.5)
		elseif self.selected == 3 then
			scene_utils:change_scene("scene_snake", 10,10, 1, 0.8)
		elseif self.selected == 4 then
			local settings_ok = scene_utils:change_scene(
				"scene_snake",
				self.custom_width, self.custom_height,
				self.custom_max_points,
				self.custom_difficulty_factor
			)
			if not settings_ok then
				scene_utils:change_scene(
					"scene_snake",
					self.custom_width, self.custom_height,
					self.custom_max_points,
					self.custom_difficulty_factor
				)
			end
		elseif self.selected == 5 then
			term.write(term:esc_pos(center_x, self.selected+#self.title_text).."     "); term.flush()
			term.write("Enter new width:        ")
			term.flush()
			self.custom_width = math.floor(tonumber(term:read_line()) or self.custom_width)
		elseif self.selected == 6 then
			term.write(term:esc_pos(center_x, self.selected+#self.title_text).."     "); term.flush()
			term.write("Enter new height:       ")
			term.flush()
			self.custom_height = math.floor(tonumber(term:read_line()) or self.custom_height)
		elseif self.selected == 7 then
			term.write(term:esc_pos(center_x, self.selected+#self.title_text).."     "); term.flush()
			term.write("Enter new maximum amount of points on screen:")
			term.flush()
			self.custom_max_points = tonumber(term:read_line()) or self.custom_max_points
		elseif self.selected == 8 then
			term.write(term:esc_pos(center_x, self.selected+#self.title_text).."     "); term.flush()
			term.write("Enter new difficulty factor(0-1):")
			term.flush()
			self.custom_difficulty_factor = tonumber(term:read_line()) or self.custom_difficulty_factor
		end
	elseif (combined=="up") then
		self.selected = math.max(self.selected - 1, 1)
	elseif (combined=="down") then
		self.selected = math.min(self.selected + 1, 8)
	end
end

function scene:output()
	term.write(term.esc_reset_sgr)
	term.write(term.esc_clear)
	term.write(term:esc_pos())

	local center_x = term:get_center_rect_position(#self.title_text[1])

	term:print_lines_at(center_x, 1, self.title_text)
	local function print_menu_item(i, desc)
		local sel = (i==self.selected) and "[*]" or "[ ]"
		term:print_at(center_x, i+#self.title_text, (" %s %15s"):format(sel, desc))
	end
	local function print_input_menu_item(i, desc, value)
		local sel = (i==self.selected) and "[_]" or "[ ]"
		--term:print_at(center_x, i+#self.title_text, sel..desc)
		term:print_at(center_x, i+#self.title_text, ("  %s %15s: %s"):format(sel, desc, value))
	end
	print_menu_item(1, "Easy")
	print_menu_item(2, "Medium")
	print_menu_item(3, "Hard")
	if self.selected >= 4 then
		print_menu_item(4, "Custom>")
		print_input_menu_item(5, "Width", self.custom_width)
		print_input_menu_item(6, "Height", self.custom_height)
		print_input_menu_item(7, "Max points", self.custom_max_points)
		print_input_menu_item(8, "Dif. factor", self.custom_difficulty_factor)
	else
		print_menu_item(4, "Custom")
	end

	term.write(term:esc_pos(1,1))
	term.flush()

end

function scene:on_update()
	self:output()
	self:input()
end

function scene:on_enter()
	self.selected = 1
	self.custom_width = 10
	self.custom_height = 10
	self.custom_max_points = 2
	self.custom_difficulty_factor = 0.2
end

return scene

