local M = {}

local controller = require("atlas.bitbucket.panel.tabs.pr.commits.controller")
local renderer = require("atlas.bitbucket.panel.tabs.pr.commits.renderer")
local keymap = require("atlas.bitbucket.panel.tabs.pr.commits.keymap")

---@param pr BitbucketPR|nil
function M.activate(pr)
	keymap.setup()
	controller.show(pr)
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

---@param opts? { force_load?: boolean }
function M.refresh(opts)
	controller.refresh(opts)
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
