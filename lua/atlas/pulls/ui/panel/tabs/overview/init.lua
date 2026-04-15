local M = {}

local utils = require("atlas.shared.utils")
local panel_state = require("atlas.pulls.ui.panel.state")
local header = require("atlas.pulls.ui.panel.components.header")
local chips = require("atlas.pulls.ui.panel.components.chips")
local panel_tabs = require("atlas.pulls.ui.panel.components.tabs")

local PADDING_X = 1
local PADDING = string.rep(" ", PADDING_X)

---@param pr PullRequest
---@param width integer
---@return string[], table[]
local function render_description(pr, width)
	local lines = {}
	local spans = {}
	local content_width = math.max(10, width - (PADDING_X * 2))

	local desc_header = "Description"
	table.insert(lines, PADDING .. desc_header)
	table.insert(spans, {
		line = 0,
		start_col = PADDING_X,
		end_col = PADDING_X + #desc_header,
		hl_group = "AtlasColumnHeader",
	})

	local desc_text = tostring(pr.description or "")
	local desc_lines = utils.sanitize_lines(desc_text)
	for _, line in ipairs(desc_lines) do
		local wrapped = utils.wrap_line(line, content_width)
		for _, chunk in ipairs(wrapped) do
			table.insert(lines, PADDING .. chunk)
		end
	end

	return lines, spans
end

---@param width integer
---@return string[], table[], table<integer, table>
function M.render(width)
	local pr = panel_state.current_pr
	if pr == nil then
		return { "", "  Nothing selected..." }, {}, {}
	end

	local state = require("atlas.pulls.state")
	local provider = state.provider

	local extra_rows = provider and provider.panel_header_rows and provider.panel_header_rows(pr) or nil
	local extra_chips = provider and provider.panel_chips and provider.panel_chips(pr) or nil

	local lines = {}
	local spans = {}

	-- Header
	local h_lines, h_spans = header.render(pr, width, extra_rows)
	utils.append_block(lines, spans, { lines = h_lines, highlights = h_spans })

	-- Chips
	local chip_line, chip_spans = chips.render(pr, { extra_chips = extra_chips })
	table.insert(lines, chip_line)
	local chip_base = #lines - 1
	for _, span in ipairs(chip_spans) do
		table.insert(spans, {
			line = chip_base,
			start_col = span.start_col,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end
	table.insert(lines, "")

	-- Tabs
	local tab_lines, tab_spans = panel_tabs.render(panel_state.current_tab, { width = width, padding_x = PADDING_X })
	utils.append_block(lines, spans, { lines = tab_lines, highlights = tab_spans })
	table.insert(lines, "")

	-- Description
	local desc_lines, desc_spans = render_description(pr, width)
	utils.append_block(lines, spans, { lines = desc_lines, highlights = desc_spans })

	panel_state.line_map = {}
	return lines, spans, panel_state.line_map
end

return M
