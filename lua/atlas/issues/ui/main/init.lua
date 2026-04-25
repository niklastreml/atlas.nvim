local M = {}

local layout = require("atlas.ui.layout")
local ui_state = require("atlas.ui.state")
local footer = require("atlas.ui.components.footer")
local ns = vim.api.nvim_create_namespace("atlas.ui")

---@param buf integer
---@param spans table[]
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

	local state = require("atlas.issues.state")
	ui_state.current_view = state.provider and state.provider.id or "issues"

	local width = vim.api.nvim_win_get_width(win)
	local height = vim.api.nvim_win_get_height(win)
	local lines, spans, line_map = require("atlas.issues.ui.main.renderer").render({
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

---@param provider IssuesProvider
function M.init(provider)
	local state = require("atlas.issues.state")
	local controller = require("atlas.issues.ui.main.controller")
	local keymaps = require("atlas.issues.ui.main.keymaps")
	state.provider = provider
	state.error = nil
	state.issues = nil
	state.issue_tree = nil
	state.line_map = {}
	state.collapsed_issue_keys = {}

	if provider.setup then
		provider.setup()
	end

	local views = provider.views and provider.views() or {}
	state.active_view = views[1]

	footer.clear_items()

	local buf = layout.buf_id("main")
	if buf ~= nil and vim.api.nvim_buf_is_valid(buf) then
		keymaps.register(buf, views)
	end

	if state.active_view == nil then
		state.error = "No issues view configured"
		M.render()
		return
	end

	ui_state.current_view = provider.id
	M.render()
	controller.switch_view(state.active_view)
end

return M
