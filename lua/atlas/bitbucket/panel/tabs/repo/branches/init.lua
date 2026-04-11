local M = {}

local controller = require("atlas.bitbucket.panel.tabs.repo.branches.controller")
local renderer = require("atlas.bitbucket.panel.tabs.repo.branches.renderer")
local keymap = require("atlas.bitbucket.panel.tabs.repo.branches.keymap")

---@param repo table|nil
function M.activate(repo)
	keymap.setup()
	controller.show(repo)
end

function M.deactivate()
	keymap.teardown()
	controller.deactivate()
end

function M.reset()
	controller.reset()
end

---@param lnum integer
---@return boolean
function M.is_selectable_line(lnum)
	return controller.is_selectable_line(lnum)
end

function M.refresh()
	controller.refresh()
end

---@return boolean
function M.is_loading()
	return controller.is_loading()
end

---@param width integer
---@return string[], table[], table|nil
function M.render(width)
	return renderer.render(width)
end

return M
