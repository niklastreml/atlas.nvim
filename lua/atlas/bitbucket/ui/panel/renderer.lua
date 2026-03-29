local M = {}

local layout = require("atlas.ui.layout")
local state = require("atlas.bitbucket.ui.panel.state")
local header = require("atlas.bitbucket.ui.panel.components.header")
local chips = require("atlas.bitbucket.ui.panel.components.chips")
local tab_content = require("atlas.bitbucket.ui.panel.components.content")
local tabs = require("atlas.bitbucket.ui.panel.components.tabs")

local ns = vim.api.nvim_create_namespace("atlas.bitbucket.panel")
local PADDING_X = 2

local function pad_line(line)
	local pad = string.rep(" ", PADDING_X)
	return pad .. (line or "") .. pad
end

---@param pr table|nil
---@param width integer
local function lines_for_pr(pr, width)
	if pr == nil then
		return {
			lines = {
				pad_line(""),
				pad_line("Nothing selected..."),
			},
			spans = {},
		}
	end

	local lines = {}
	local spans = {}

	--- Header
	local header_lines, header_spans = header.render(pr, (width or 1) - (PADDING_X * 2))
	local header_base = #lines
	for _, line in ipairs(header_lines) do
		table.insert(lines, pad_line(line))
	end
	for _, span in ipairs(header_spans or {}) do
		if span.line_hl_group ~= nil then
			table.insert(spans, {
				line = header_base + span.line,
				start_col = 0,
				end_col = 0,
				line_hl_group = span.line_hl_group,
			})
		else
			table.insert(spans, {
				line = header_base + span.line,
				start_col = span.start_col + PADDING_X,
				end_col = span.end_col + PADDING_X,
				hl_group = span.hl_group,
			})
		end
	end

	table.insert(lines, pad_line(""))

	--- Chips
	local chip_line, chip_spans = chips.render(pr)
	local chip_line_index = #lines
	table.insert(lines, pad_line(chip_line))
	for _, span in ipairs(chip_spans) do
		table.insert(spans, {
			line = chip_line_index,
			start_col = span.start_col + PADDING_X,
			end_col = span.end_col + PADDING_X,
			hl_group = span.hl_group,
		})
	end
	table.insert(lines, pad_line(""))

	--- Tabs
	local tabs_line, tabs_spans = tabs.render(state.current_tab)
	local tabs_line_index = #lines
	table.insert(lines, pad_line(tabs_line))
	for _, span in ipairs(tabs_spans) do
		table.insert(spans, {
			line = tabs_line_index,
			start_col = span.start_col + PADDING_X,
			end_col = span.end_col + PADDING_X,
			hl_group = span.hl_group,
		})
	end
	local rule_width = math.max(1, width)
	table.insert(lines, string.rep("─", rule_width))

	--- Content
	local body_lines, body_spans = tab_content.render(
		state.current_tab,
		pr,
		state.current_pr_detail,
		state.current_pr_commits,
		state.current_pr_diffstat,
		state.current_pr_diff,
		(width or 1) - (PADDING_X * 2)
	)
	local body_base = #lines
	for _, line in ipairs(body_lines) do
		table.insert(lines, pad_line(line))
	end
	for _, span in ipairs(body_spans or {}) do
		table.insert(spans, {
			line = body_base + span.line,
			start_col = span.start_col + PADDING_X,
			end_col = span.end_col + PADDING_X,
			hl_group = span.hl_group,
		})
	end

	return { lines = lines, spans = spans }
end

function M.render()
	local buf = layout.buf_id("detail")
	local win = layout.win_id("detail")
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	if win == nil or not vim.api.nvim_win_is_valid(win) then
		return
	end

	local payload = lines_for_pr(state.current_pr, vim.api.nvim_win_get_width(win))

	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, payload.lines)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	for _, span in ipairs(payload.spans or {}) do
		if span.line_hl_group ~= nil then
			vim.api.nvim_buf_set_extmark(buf, ns, span.line, 0, {
				line_hl_group = span.line_hl_group,
			})
		else
			vim.api.nvim_buf_set_extmark(buf, ns, span.line, span.start_col, {
				end_row = span.line,
				end_col = span.end_col,
				hl_group = span.hl_group,
			})
		end
	end

	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
end

return M
