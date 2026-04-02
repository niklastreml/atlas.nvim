local M = {}
local state = require("atlas.jira.panel.tabs.comments.state")
local header = require("atlas.jira.panel.components.header")
local tabs = require("atlas.jira.panel.components.tabs")
local utils = require("atlas.utils")
local spinner = require("atlas.ui.components.spinner")
local adf = require("atlas.jira.panel.tabs.overview.adf")
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
	local tabs_lines, tabs_spans = tabs.render("comments", width, PADDING_X)
	utils.append_block(lines, spans, { lines = tabs_lines, highlights = tabs_spans })
	utils.append_block(lines, spans, { lines = { "" }, highlights = {} })

	if type(state.comments) == "table" and #state.comments > 0 then
		for idx, comment in ipairs(state.comments) do
			local body = adf.to_markdown((comment or {}).body)
			if body == "" then
				body = "-"
			end
			for _, row in ipairs(utils.sanitize_markdown_lines(body)) do
				table.insert(lines, string.rep(" ", PADDING_X) .. row)
			end
			if idx < #state.comments then
				table.insert(lines, "")
			end
		end
		table.insert(lines, "")
	elseif state.state ~= "loading" then
		table.insert(lines, string.rep(" ", PADDING_X) .. "No comments")
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #lines[#lines],
			hl_group = "AtlasTextMuted",
		})
	end

	if state.state == "loading" then
		local loading = string.rep(" ", PADDING_X) .. spinner.with_text("Loading comments...")
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
		[#lines] = { kind = "comments" },
	}

	return lines, spans, state.line_map
end

return M
