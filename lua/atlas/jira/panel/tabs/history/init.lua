local M = {}

local controller = require("atlas.jira.panel.tabs.history.controller")
local renderer = require("atlas.jira.panel.tabs.history.renderer")
local keymap = require("atlas.jira.panel.tabs.history.keymap")

---@param issue JiraIssue|nil
---@param opts? { force_refresh?: boolean }
function M.activate(issue, opts)
	keymap.setup()
	controller.show(issue, opts)
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
