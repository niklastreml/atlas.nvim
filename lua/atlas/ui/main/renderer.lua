local M = {}

local state = require("atlas.ui.main.state")
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

---@param view "bitbucket"|"jira"
---@param opts { force_refresh?: boolean, autofocus?: boolean }|nil
function M.render(view, opts)
	local layout = require("atlas.ui.layout")
	local win = layout.win_id("main")
	local buf = layout.buf_id("main")
	if win == nil or buf == nil then
		return
	end

	local lines = {}
	local spans = {}
	local line_map = {}

	local target_view = view or state.current_view or "jira"
	local width = vim.api.nvim_win_get_width(win)
	local height = vim.api.nvim_win_get_height(win)

	if target_view == "jira" then
		state.current_view = "jira"
		local jira_state = require("atlas.jira.state")
		local should_refresh = (opts and opts.force_refresh)
			or (not jira_state.is_loading and jira_state.issue_tree == nil and jira_state.error == nil)
		if should_refresh then
			require("atlas.jira.ui.controller").refresh_current_view(function()
				if opts and opts.autofocus then
					require("atlas.ui.navigation").focus_first_item()
				end
			end)
		end

		lines, spans, line_map = require("atlas.jira.ui.renderer").render({ width = width, height = height })
	elseif target_view == "bitbucket" then
		state.current_view = "bitbucket"
		local bitbucket_state = require("atlas.bitbucket.state")
		local should_refresh = (opts and opts.force_refresh)
			or (not bitbucket_state.is_loading and bitbucket_state.repos == nil and bitbucket_state.error == nil)
		if should_refresh then
			require("atlas.bitbucket.ui.main.controller").refresh_current_view(function()
				if opts and opts.autofocus then
					require("atlas.ui.navigation").focus_first_item()
				end
			end)
		end

		lines, spans, line_map = require("atlas.bitbucket.ui.main.renderer").render({ width = width, height = height })
	end

	state.line_map = line_map or {}

	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or {})
	apply_spans(buf, spans)
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

	if opts and opts.autofocus then
		require("atlas.ui.navigation").focus_first_item()
	end

	require("atlas.ui.components.footer").refresh()
end

return M
