local M = {}
local icons = require("atlas.ui.icons")
local tabs = require("atlas.ui.components.tabs")

local PR_TABS = {
	{ key = "overview", label = "Overview", icon = icons.entity("overview") },
	{ key = "activity", label = "Activity", icon = icons.entity("activity") },
	{ key = "comments", label = "Comments", icon = icons.entity("comment") },
	{ key = "commits", label = "Commits", icon = icons.entity("commit") },
	{ key = "files", label = "File changes", icon = icons.entity("files") },
}

local REPO_TABS = {
	{ key = "overview", label = "Overview", icon = icons.entity("overview") },
	{ key = "branches", label = "Branches", icon = icons.entity("branch") },
	{ key = "tags", label = "Tags", icon = icons.entity("tag") },
}

---@param active_tab "overview"|"activity"|"comments"|"commits"|"files"
---@param width integer
---@param padding_x integer
---@return string[] lines
---@return table[] spans
function M.render_pr(active_tab, width, padding_x)
	return tabs.render(PR_TABS, active_tab, width, {
		active_hl = nil,
		inactive_hl = "AtlasTextMuted",
		gap = " ",
		padding_x = padding_x,
	})
end

---@param active_tab "overview"|"branches"|"tags"
---@param width integer
---@param padding_x integer
---@return string[] lines
---@return table[] spans
function M.render_repo(active_tab, width, padding_x)
	return tabs.render(REPO_TABS, active_tab, width, {
		active_hl = nil,
		inactive_hl = "AtlasTextMuted",
		gap = " ",
		padding_x = padding_x,
	})
end

return M
