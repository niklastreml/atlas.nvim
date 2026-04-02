local M = {}

local controller = require("atlas.jira.panel.tabs.overview.controller")
local renderer = require("atlas.jira.panel.tabs.overview.renderer")
local keymap = require("atlas.jira.panel.tabs.overview.keymap")

---@param issue JiraIssue|nil
function M.activate(issue)
	keymap.setup()
	controller.show(issue)
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
