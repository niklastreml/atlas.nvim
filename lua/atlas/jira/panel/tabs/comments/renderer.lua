local M = {}
local state = require("atlas.jira.panel.tabs.comments.state")
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
	local header_lines, header_spans = header.render(issue, width)
	utils.append_block(lines, spans, { lines = header_lines, highlights = header_spans })
	utils.append_block(lines, spans, { lines = { "" }, highlights = {} })
	local tabs_lines, tabs_spans = tabs.render("comments", width, PADDING_X)
	utils.append_block(lines, spans, { lines = tabs_lines, highlights = tabs_spans })
	table.insert(lines, "")

	if state.comments_text == "loading" then
		local loading = string.rep(" ", PADDING_X) .. spinner.with_text("Loading comments...")
		table.insert(lines, loading)
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #loading,
			hl_group = "AtlasTextMuted",
		})
	elseif type(state.comments_text) == "string" and state.comments_text ~= "" then
		for _, row in ipairs(utils.sanitize_markdown_lines(state.comments_text)) do
			table.insert(lines, string.rep(" ", PADDING_X) .. row)
		end
	else
		table.insert(lines, string.rep(" ", PADDING_X) .. "No comments")
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #lines[#lines],
			hl_group = "AtlasTextMuted",
		})
	end

	state.line_map = {
		[1] = { kind = "issue", issue = issue },
		[#lines] = { kind = "comments" },
	}

	return lines, spans, state.line_map
end

return M
