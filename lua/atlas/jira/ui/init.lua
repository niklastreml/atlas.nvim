local M = {}

local layout = require("atlas.ui.layout")
local ui_state = require("atlas.ui.state")
local footer = require("atlas.ui.components.footer")
local ns = vim.api.nvim_create_namespace("atlas.ui")

local function apply_spans(buf, spans)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	for _, span in ipairs(spans or {}) do
		vim.api.nvim_buf_set_extmark(buf, ns, span.line, span.start_col, {
			end_row = span.line,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end
end

function M.render()
	local win = layout.win_id("main")
	local buf = layout.buf_id("main")
	if win == nil or buf == nil then
		return
	end

	ui_state.current_view = "jira"

	local width = vim.api.nvim_win_get_width(win)
	local height = vim.api.nvim_win_get_height(win)
	local lines, spans, line_map = require("atlas.jira.ui.renderer").render({
		width = width,
		height = height,
	})

	ui_state.line_map = line_map or {}

	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or {})
	apply_spans(buf, spans)
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

	footer.refresh()
end

function M.init()
	local state = require("atlas.jira.state")
	local controller = require("atlas.jira.ui.controller")
	controller.switch_view(state.active_view)
end

return M
