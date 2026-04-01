local M = {}
local state = require("atlas.jira.panel.tabs.overview.state")
local header = require("atlas.jira.panel.components.header")
local tabs = require("atlas.jira.panel.components.tabs")
local utils = require("atlas.utils")
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
	local header_lines, header_spans = header.render(issue, width)
	utils.append_block(lines, spans, { lines = header_lines, highlights = header_spans })
	utils.append_block(lines, spans, { lines = { "" }, highlights = {} })
	local tabs_lines, tabs_spans = tabs.render("overview", width, PADDING_X)

	utils.append_block(lines, spans, { lines = tabs_lines, highlights = tabs_spans })
	table.insert(lines, "")

	table.insert(lines, "Overview tab content goes here...")
	state.line_map = {
		[1] = { kind = "issue", issue = issue },
		[#lines] = { kind = "overview" },
	}

	return lines, spans, state.line_map
end

return M
