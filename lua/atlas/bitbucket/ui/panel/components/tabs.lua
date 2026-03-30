local M = {}
local icons = require("atlas.ui.icons")

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
	{ key = "tags", label = "Tags", icon = icons.fallback() },
}

---@param tabs table[]
---@param active_tab string
---@return string
---@return table[]
local function render_tabs(tabs, active_tab)
	local line = ""
	local spans = {}
	local col = 0

	for i, tab in ipairs(tabs) do
		local part = string.format("%s %s ", tab.icon, tab.label)

		line = line .. part
		if tab.key ~= active_tab then
			table.insert(spans, {
				start_col = col,
				end_col = col + #part,
				hl_group = "AtlasTextMuted",
			})
		end
		col = col + #part

		if i < #tabs then
			line = line .. " "
			col = col + 1
		end
	end

	return line, spans
end

---@param active_tab "overview"|"activity"|"comments"|"commits"|"files"
---@return string line
---@return table[] spans
function M.render_pr(active_tab)
	return render_tabs(PR_TABS, active_tab)
end

---@param active_tab "overview"|"branches"|"tags"
---@return string line
---@return table[] spans
function M.render_repo(active_tab)
	return render_tabs(REPO_TABS, active_tab)
end

return M
