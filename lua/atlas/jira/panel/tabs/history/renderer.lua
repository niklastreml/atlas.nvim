local M = {}
local state = require("atlas.jira.panel.tabs.history.state")
local header = require("atlas.jira.panel.components.header")
local tabs = require("atlas.jira.panel.components.tabs")
local utils = require("atlas.utils")
local spinner = require("atlas.ui.components.spinner")
local PADDING_X = 2

---@param width integer
---@return string[], table[], table|nil
function M.render(width)
	local issue = state.issue
	if issue == nil then
		state.line_map = {}
		return { "", "  Nothing selected..." }, {}, state.line_map
	end

	local lines, spans = {}, {}

	--- Header
	local header_lines, header_spans = header.render(issue, width)
	utils.append_block(lines, spans, { lines = header_lines, highlights = header_spans })
	utils.append_block(lines, spans, { lines = { "" }, highlights = {} })

	--- Tabs
	local tabs_lines, tabs_spans = tabs.render("history", width, PADDING_X)
	utils.append_block(lines, spans, { lines = tabs_lines, highlights = tabs_spans })
	utils.append_block(lines, spans, { lines = { "" }, highlights = {} })

	--- Content
	if type(state.history_items) == "table" and #state.history_items > 0 then
		for _, entry in ipairs(state.history_items) do
			for _, item in ipairs(entry.items or {}) do
				local from = item.from_string or item.from or ""
				local to = item.to_string or item.to or ""
				table.insert(lines, string.rep(" ", PADDING_X) .. string.format("%s -> %s", tostring(from), tostring(to)))
			end
		end
	elseif not state.is_loading then
		table.insert(lines, string.rep(" ", PADDING_X) .. "No history")
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #lines[#lines],
			hl_group = "AtlasTextMuted",
		})
	end

	if state.is_loading then
		local loading = string.rep(" ", PADDING_X) .. spinner.with_text("Loading history...")
		table.insert(lines, loading)
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #loading,
			hl_group = "AtlasTextMuted",
		})
	end

	state.line_map = {
		[1] = { kind = "issue", issue = issue },
		[#lines] = { kind = "history" },
	}

	return lines, spans, state.line_map
end

return M
