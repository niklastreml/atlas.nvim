local M = {}

local TABS = {
	{ key = "overview", label = "Overview" },
	{ key = "commits", label = "Commits" },
	{ key = "files", label = "File changes" },
}

---@param active_tab "overview"|"commits"|"files"
---@return string line
---@return table[] spans
function M.render(active_tab)
	local line = ""
	local spans = {}
	local col = 0

	for i, tab in ipairs(TABS) do
		local part = string.format(" %s ", tab.label)

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
