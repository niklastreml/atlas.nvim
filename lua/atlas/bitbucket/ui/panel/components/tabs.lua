local M = {}
local icons = require("atlas.ui.icons")

local TABS = {
	{ key = "overview", label = "Overview", icon = icons.entity("overview") },
	{ key = "activity", label = "Activity", icon = icons.entity("activity") },
	{ key = "comments", label = "Comments", icon = icons.entity("comment") },
	{ key = "commits", label = "Commits", icon = icons.entity("commit") },
	{ key = "files", label = "File changes", icon = icons.entity("files") },
}

---@param active_tab "overview"|"activity"|"comments"|"commits"|"files"
---@return string line
---@return table[] spans
function M.render(active_tab)
	local line = ""
	local spans = {}
	local col = 0

	for i, tab in ipairs(TABS) do
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

		if i < #TABS then
			line = line .. " "
			col = col + 1
		end
	end

	return line, spans
end

return M
