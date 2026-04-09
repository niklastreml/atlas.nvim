local M = {}

local controller = require("atlas.bitbucket.panel.tabs.pr.comments.controller")
local renderer = require("atlas.bitbucket.panel.tabs.pr.comments.renderer")
local keymap = require("atlas.bitbucket.panel.tabs.pr.comments.keymap")

---@param pr BitbucketPR|nil
function M.activate(pr)
	keymap.setup()
	controller.show(pr)
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

function M.refresh()
	controller.refresh()
end


---@param width integer
---@return string[], table[], table|nil
function M.render(width)
	return renderer.render(width)
end

return M
