local M = {}

local layout = require("atlas.ui.layout")
local panel_state = require("atlas.pulls.ui.panel.state")

local ns = vim.api.nvim_create_namespace("atlas.panel")

local TABS = {
	{ key = "overview", mod = "atlas.pulls.ui.panel.tabs.overview" },
}

---@param tab_key string
---@return table|nil
local function get_tab_module(tab_key)
	for _, tab in ipairs(TABS) do
		if tab.key == tab_key then
			return require(tab.mod)
		end
	end
	return nil
end

---@return boolean
function M.is_open()
	return layout.win_id("detail") ~= nil
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

	local lines = {}
	local spans = {}

	if panel_state.current_pr == nil then
		lines = { "", "  Nothing selected..." }
		panel_state.line_map = {}
	else
		local tab = get_tab_module(panel_state.current_tab)
		if tab and type(tab.render) == "function" then
			local tab_line_map
			lines, spans, tab_line_map = tab.render(vim.api.nvim_win_get_width(win))
			panel_state.line_map = tab_line_map or {}
		else
			lines = { "", "  Unknown tab: " .. tostring(panel_state.current_tab) }
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
		elseif type(span) == "table" and span.line ~= nil and span.start_col ~= nil and span.end_col ~= nil and span.hl_group ~= nil then
			vim.api.nvim_buf_set_extmark(buf, ns, span.line, span.start_col, {
				end_row = span.line,
				end_col = span.end_col,
				hl_group = span.hl_group,
			})
		end
	end

	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
end

---@param pr PullRequest|nil
---@param repo PullsRepo|nil
function M.on_select(pr, repo)
	if pr == nil then
		return
	end

	local same_pr = panel_state.current_pr ~= nil
		and tostring(panel_state.current_pr.id) == tostring(pr.id)
		and tostring(panel_state.current_pr.repo_id) == tostring(pr.repo_id)

	panel_state.current_pr = pr
	panel_state.current_repo = repo

	if not same_pr then
		panel_state.current_tab = "overview"
	end

	if M.is_open() then
		M.render()
	end
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

	panel_state.current_tab = TABS[next_idx].key
	M.render()
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

	panel_state.current_tab = TABS[prev_idx].key
	M.render()
end

function M.close()
	panel_state.reset()
end

return M
