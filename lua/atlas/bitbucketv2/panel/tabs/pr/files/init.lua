local M = {}

local controller = require("atlas.bitbucketv2.panel.tabs.pr.files.controller")
local renderer = require("atlas.bitbucketv2.panel.tabs.pr.files.renderer")
local keymap = require("atlas.bitbucketv2.panel.tabs.pr.files.keymap")

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


---@param width integer
---@return string[], table[], table|nil
function M.render(width)
	return renderer.render(width)
end

return M
