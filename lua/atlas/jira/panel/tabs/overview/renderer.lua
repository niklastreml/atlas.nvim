local M = {}
local state = require("atlas.jira.panel.tabs.overview.state")
local header = require("atlas.jira.panel.components.header")
local tabs = require("atlas.jira.panel.components.tabs")
local chips = require("atlas.jira.panel.components.chips")
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
	local tabs_lines, tabs_spans = tabs.render("overview", width, PADDING_X)
	utils.append_block(lines, spans, { lines = tabs_lines, highlights = tabs_spans })

	--- Chips
	local mode_text = state.view_mode == "raw" and "ADF (m)" or "Markdown (m)"
	local mode_line, mode_spans = chips.render({
		{ text = mode_text, hl_group = "AtlasChipActive", active = true },
	}, width, nil, "right")
	table.insert(lines, mode_line)
	for _, span in ipairs(mode_spans) do
		table.insert(spans, {
			line = #lines - 1,
			start_col = span.start_col,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end

	--- Content
	if state.adf_description == "loading" then
		local loading = string.rep(" ", PADDING_X) .. spinner.with_text("Loading description...")
		table.insert(lines, loading)
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #loading,
			hl_group = "AtlasTextMuted",
		})
	elseif state.adf_description == nil or (state.view_mode == "markdown" and state.md_description == "") then
		table.insert(lines, string.rep(" ", PADDING_X) .. "No description")
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #lines[#lines],
			hl_group = "AtlasTextMuted",
		})
	else
		table.insert(lines, string.rep(" ", PADDING_X) .. "Description")
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #lines[#lines],
			hl_group = "AtlasTextMuted",
		})

		local desc_lines
		if state.view_mode == "raw" then
			local raw_text = vim.inspect(state.adf_description)
			desc_lines = vim.split(raw_text, "\n", { plain = true })
		else
			desc_lines = utils.sanitize_markdown_lines(state.md_description or "")
		end

		for _, desc_line in ipairs(desc_lines) do
			table.insert(lines, string.rep(" ", PADDING_X) .. desc_line)
		end
	end

	state.line_map = {
		[1] = { kind = "issue", issue = issue },
		[#lines] = { kind = "overview" },
	}

	return lines, spans, state.line_map
end

return M
