local M = {}
local icons = require("atlas.ui.icons")
local tabs = require("atlas.ui.components.tabs")

local JIRA_TABS = {
	{ key = "overview", label = "Overview", icon = icons.entity("overview") },
	{ key = "comments", label = "Comments", icon = icons.entity("comment") },
	{ key = "worklogs", label = "Worklogs", icon = icons.entity("activity") },
}

---@param active_tab "overview"|"comments"|"worklogs"
---@param width integer
---@param padding_x integer
---@return string[]
---@return table[]
function M.render(active_tab, width, padding_x)
	return tabs.render(JIRA_TABS, active_tab, width, {
		active_hl = nil,
		inactive_hl = "AtlasTextMuted",
		gap = " ",
		padding_x = padding_x,
	})
end

return M
