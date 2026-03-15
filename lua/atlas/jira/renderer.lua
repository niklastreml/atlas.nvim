local M = {}

local ui_state = require("atlas.ui.state")
local ui_navbar = require("atlas.ui.components.navbar")
local ui_table = require("atlas.ui.components.table")
local cfg = require("atlas.config")
local state = require("atlas.jira.state")
local view = require("atlas.jira.views.board")

local ns = vim.api.nvim_create_namespace("atlas.jira")

local function append_block(lines, spans, block)
	local base = #lines
	for _, line in ipairs(block.lines or {}) do
		table.insert(lines, line)
	end
	for _, span in ipairs(block.highlights or {}) do
		table.insert(spans, {
			line = base + span.line,
			start_col = span.start_col,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end
end

function M.render()
	if ui_state.buf_id == nil or not vim.api.nvim_buf_is_valid(ui_state.buf_id) then
		return
	end

	local width = vim.api.nvim_win_get_width(ui_state.win_id)
	local lines, spans = {}, {}

	local labels = cfg.get_view_labels("jira")
	if state.current_view == nil and #labels > 0 then
		state.current_view = labels[1]
	end
	append_block(
		lines,
		spans,
		ui_navbar.render({
			current_view = state.current_view,
			views = labels,
			width = width,
		})
	)
	table.insert(lines, "")

	local payload = view.build(width)
	local body_lines, line_map, body_spans = ui_table.render(payload.columns, payload.rows)

	local body_start = #lines
	for _, line in ipairs(body_lines) do
		table.insert(lines, line)
	end
	for _, span in ipairs(body_spans) do
		table.insert(spans, {
			line = body_start + span.line,
			start_col = span.start_col,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end

	state.line_map = {}
	for lnum, item in pairs(line_map or {}) do
		state.line_map[body_start + lnum] = item
	end

	vim.api.nvim_set_option_value("modifiable", true, { buf = ui_state.buf_id })
	vim.api.nvim_buf_set_lines(ui_state.buf_id, 0, -1, false, lines)
	vim.api.nvim_buf_clear_namespace(ui_state.buf_id, ns, 0, -1)
	for _, s in ipairs(spans) do
		vim.api.nvim_buf_set_extmark(ui_state.buf_id, ns, s.line, s.start_col, {
			end_row = s.line,
			end_col = s.end_col,
			hl_group = s.hl_group,
		})
	end
	vim.api.nvim_set_option_value("modifiable", false, { buf = ui_state.buf_id })
end

return M
