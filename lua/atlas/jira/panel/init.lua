local M = {}

local panel_state = require("atlas.jira.panel.state")
local layout = require("atlas.ui.layout")

local TABS = {
	{ key = "overview", label = "Overview", mod = "atlas.jira.panel.tabs.overview" },
	{ key = "comments", label = "Comments", mod = "atlas.jira.panel.tabs.comments" },
	{ key = "worklogs", label = "Worklogs", mod = "atlas.jira.panel.tabs.worklogs" },
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

---@param issue table|nil
function M.on_select(issue)
	panel_state.set_current(issue)
	if issue ~= nil then
		M.select_tab("overview")
	else
		M.render()
	end
end

---@param tab_key string
function M.select_tab(tab_key)
	local old_tab = get_tab_module(panel_state.current_tab)
	if old_tab then
		old_tab.deactivate()
	end

	panel_state.set_current_tab(tab_key)

	local new_tab = get_tab_module(tab_key)
	if new_tab then
		new_tab.activate(panel_state.current_issue)
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
		return
	end
	if win == nil or not vim.api.nvim_win_is_valid(win) then
		return
	end

	local lines = {}

	if panel_state.current_issue == nil then
		lines = { "", "  Nothing selected..." }
	else
		local issue = panel_state.current_issue
		table.insert(lines, "")
		table.insert(lines, "  " .. tostring((issue._item or {}).key or issue.id or ""))
		table.insert(lines, "  " .. tostring(issue.title or issue.name or ""))
		table.insert(lines, "")
		table.insert(lines, "  [" .. panel_state.current_tab .. "]")
		table.insert(lines, "")
		table.insert(lines, "  Panel content goes here...")
	end

	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
end

function M.refresh()
	M.render()
end

return M
