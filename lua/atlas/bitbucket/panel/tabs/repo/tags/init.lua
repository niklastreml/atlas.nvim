local M = {}

local controller = require("atlas.bitbucket.panel.tabs.repo.tags.controller")
local renderer = require("atlas.bitbucket.panel.tabs.repo.tags.renderer")
local keymap = require("atlas.bitbucket.panel.tabs.repo.tags.keymap")

---@param repo table|nil
function M.activate(repo)
	keymap.setup()
	controller.show(repo)
	controller.move(0)
end

function M.deactivate()
	keymap.teardown()
	controller.deactivate()
end

---@param delta integer
function M.move_cursor(delta)
	controller.move(delta)
end


---@param width integer
---@return string[], table[], table|nil
function M.render(width)
	return renderer.render(width)
end

return M
