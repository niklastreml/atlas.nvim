local M = {}

local controller = require("atlas.jira.panel.tabs.overview.controller")
local renderer = require("atlas.jira.panel.tabs.overview.renderer")
local keymap = require("atlas.jira.panel.tabs.overview.keymap")

---@param issue JiraIssue|nil
function M.activate(issue)
	keymap.setup()
	controller.fetch_if_needed(issue)
end

function M.deactivate()
	keymap.teardown()
end

---@param width integer
---@return string[], table[], table|nil
function M.render(width)
	return renderer.render(width)
end

return M
