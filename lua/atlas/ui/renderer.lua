local M = {}

local state = require("atlas.ui.state")

local ns = vim.api.nvim_create_namespace("atlas.ui")

local function apply_spans(buf, spans)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	for _, span in ipairs(spans) do
		vim.api.nvim_buf_set_extmark(buf, ns, span.line, span.start_col, {
			end_row = span.line,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end
end

---@param view "bitbucket"|"github"|"jira"
function M.render(view)
	local window = require("atlas.ui.window")
	if not window.is_open() then
		window.open()
	end

	local lines = {}
	local spans = {}
	local line_map = {}

	local width = vim.api.nvim_win_get_width(state.win_id)
	local height = vim.api.nvim_win_get_height(state.win_id)

	if view == "jira" then
		state.current_view = "jira"
		lines, spans, line_map = require("atlas.jira.ui.renderer").render(width, height)
	elseif view == "bitbucket" then
		state.current_view = "bitbucket"
		lines, spans, line_map = require("atlas.bitbucket.ui.renderer").render(width, height)
	elseif view == "github" then
		state.current_view = "github"
		lines, spans, line_map = require("atlas.github.ui.renderer").render(width, height)
	end

	local buf = state.buf_id
	state.line_map = line_map or {}

	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or {})
	apply_spans(buf, spans)
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
end

return M
