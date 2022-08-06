-- Simple, generic scene implementation.
-- Scenes simplify development of interactive applications with
-- multiple different logical "screens"(or scenes, windows).
-- Scenes are a table that support three callbacks, and need to
-- be loaded/unloaded using the change_scene() function.
-- Use `scenes:change_scene(new_scene)` to set `new_scene` to the currently active scene.
-- To unload a scene without loading a new scene simply pass `nil` to change_scene.
-- The scenes:change_scene() function will call the following callbacks if applicable:
--  * `new_scene:enter()` is called when a scene is activated
--  * `old_scene:leave()` is called when a scene is deactived
-- The optional run_scene_updates() function will call the
--  * current_scene:update() callback until `scenes.current_scene` is falsey.
local scene_utils = {}



-- change the current_scene to a new scene, by calling the respecive
-- new_scene:leave() and new_scene:enter() callbacks.
function scene_utils:change_scene(new_scene, ...)
	-- check specified scene(require if needed)
	if type(new_scene) == "string" then new_scene = require(new_scene) end

	if self.current_scene and self.current_scene.on_leave then
		-- call leave callback of previous scene if any
		local abort = self.current_scene:on_leave(new_scene)
		if abort then
			-- abort leaving if on_leave requested it
			return
		end
	end

	-- change scene(scene can be nil to quit application)
	self.current_scene = new_scene

	-- if no new scene don't call :on_enter
	if not new_scene then
		return
	end

	-- check for valid scene
	assert(type(new_scene)=="table", "Not a valid scene table!")

	if new_scene.on_enter then
		-- call enter callback of new scene if any
		return new_scene:on_enter(...)
	end
end



-- Run the update loop as long as there is a current_scene.
-- If new_scene is set, change to specified scene first.
-- If self.on_every is a function, it is called every iteration.
-- If current_scene:on_update is a function, it is called every iteration.
function scene_utils:run_scene_updates(new_scene, ...)
	-- change to initial scene, if any
	if new_scene then
		self:change_scene(new_scene, ...)
	end

	-- loop until no more scene is set
	while self.current_scene do
		if type(self.on_every) == "function" then
			self:on_every()
		end
		if type(self.current_scene.on_update) == "function" then
			self.current_scene:on_update()
		end
	end
end

return scene_utils
