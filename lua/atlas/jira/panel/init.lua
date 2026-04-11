local M = {}

local panel_state = require("atlas.jira.panel.state")
local layout = require("atlas.ui.layout")
local keymaps = require("atlas.jira.panel.keymaps")
local ns = vim.api.nvim_create_namespace("atlas.jira.panel")
local render_timer = nil
local RENDER_INTERVAL_MS = 120

local TABS = {
	{ key = "overview", label = "Overview", mod = "atlas.jira.panel.tabs.overview" },
	{ key = "comments", label = "Comments", mod = "atlas.jira.panel.tabs.comments" },
	{ key = "history", label = "History", mod = "atlas.jira.panel.tabs.history" },
}

---@return table|nil
local function get_tab_module(tab_key)
	for _, tab in ipairs(TABS) do
		if tab.key == tab_key then
			return require(tab.mod)
		end
	end
	return nil
end

---@param issue JiraIssue|nil
---@return string|nil
local function issue_key(issue)
	return issue and issue.key or nil
end

local function stop_render_loop()
	if render_timer ~= nil then
		render_timer:stop()
		render_timer:close()
		render_timer = nil
	end
end

local function active_tab_is_loading()
	local tab = get_tab_module(panel_state.current_tab)
	return tab ~= nil and type(tab.is_loading) == "function" and tab.is_loading() == true
end

local function sync_render_loop()
	if not active_tab_is_loading() then
		stop_render_loop()
		return
	end

	if render_timer ~= nil then
		return
	end

	render_timer = vim.loop.new_timer()
	if render_timer == nil then
		return
	end

	render_timer:start(
		0,
		RENDER_INTERVAL_MS,
		vim.schedule_wrap(function()
			if not active_tab_is_loading() then
				stop_render_loop()
				return
			end

			M.render()
		end)
	)
end

---@param issue JiraIssue|nil
function M.on_select(issue)
	local previous_issue = panel_state.current_issue
	local force_refresh = issue_key(previous_issue) ~= issue_key(issue)
	local target_tab = panel_state.current_tab
	if get_tab_module(target_tab) == nil then
		target_tab = "overview"
	end
	panel_state.set_current(issue)
	local buf = layout.buf_id("detail")
	if buf ~= nil then
		keymaps.register(buf)
	end

	if issue ~= nil then
		M.select_tab(target_tab, { force_refresh = force_refresh })
	else
		M.render()
	end
end

---@param tab_key string
---@param opts? { force_refresh?: boolean }
function M.select_tab(tab_key, opts)
	opts = opts or {}
	local old_tab = get_tab_module(panel_state.current_tab)
	if old_tab then
		old_tab.deactivate()
	end

	panel_state.set_current_tab(tab_key)

	local new_tab = get_tab_module(tab_key)
	if new_tab then
		new_tab.activate(panel_state.current_issue, opts)
	end

	M.render()
end

function M.next_tab()
	local idx = 1
	for i, tab in ipairs(TABS) do
		if tab.key == panel_state.current_tab then
			idx = i
			break
		end
	end

	local next_idx = idx + 1
	if next_idx > #TABS then
		next_idx = 1
	end

	M.select_tab(TABS[next_idx].key)
end

function M.prev_tab()
	local idx = 1
	for i, tab in ipairs(TABS) do
		if tab.key == panel_state.current_tab then
			idx = i
			break
		end
	end

	local prev_idx = idx - 1
	if prev_idx < 1 then
		prev_idx = #TABS
	end

	M.select_tab(TABS[prev_idx].key)
end

function M.render()
	local buf = layout.buf_id("detail")
	local win = layout.win_id("detail")
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		stop_render_loop()
		return
	end
	if win == nil or not vim.api.nvim_win_is_valid(win) then
		stop_render_loop()
		return
	end

	local lines = {}
	local spans = {}

	if panel_state.current_issue == nil then
		lines = { "", "  Nothing selected..." }
		panel_state.line_map = {}
	else
		local tab = get_tab_module(panel_state.current_tab)
		if tab and type(tab.render) == "function" then
			local tab_line_map = nil
			lines, spans, tab_line_map = tab.render(vim.api.nvim_win_get_width(win))
			panel_state.line_map = tab_line_map or {}
		else
			lines =
				{ "", "  Unknown tab: " .. tostring(panel_state.current_tab) .. ". You shouldn't even be here..󱃞 " }
			panel_state.line_map = {}
		end
	end

	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	for _, span in ipairs(spans or {}) do
		if type(span) == "table" and span.line ~= nil and span.line_hl_group ~= nil then
			vim.api.nvim_buf_set_extmark(buf, ns, span.line, 0, {
				line_hl_group = span.line_hl_group,
			})
		elseif
			type(span) == "table"
			and span.line ~= nil
			and span.start_col ~= nil
			and span.end_col ~= nil
			and span.hl_group ~= nil
		then
			vim.api.nvim_buf_set_extmark(buf, ns, span.line, span.start_col, {
				end_row = span.line,
				end_col = span.end_col,
				hl_group = span.hl_group,
			})
		end
	end
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
	sync_render_loop()
end

function M.refresh()
	M.render()
end

function M.deactivate()
	stop_render_loop()
	local tab = get_tab_module(panel_state.current_tab)
	if tab ~= nil and type(tab.deactivate) == "function" then
		tab.deactivate()
	end
end

return M
