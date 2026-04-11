local M = {}

local controller = require("atlas.bitbucket.panel.tabs.pr.overview.controller")
local renderer = require("atlas.bitbucket.panel.tabs.pr.overview.renderer")
local keymap = require("atlas.bitbucket.panel.tabs.pr.overview.keymap")

---@param pr BitbucketPR|nil
function M.activate(pr)
	keymap.setup()
	controller.show(pr)
end

function M.deactivate()
	keymap.teardown()
	controller.deactivate()
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
