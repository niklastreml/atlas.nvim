local M = {}
local state = require("atlas.jira.panel.tabs.history.state")
local panel_state = require("atlas.jira.panel.state")
local issues_api = require("atlas.jira.api.issues")
local spinner = require("atlas.ui.components.spinner")
local footer = require("atlas.ui.components.footer")

local active_handle = nil
local request_id = 0

---@return integer|nil
local function detail_win()
	local layout = require("atlas.ui.layout")
	local win = layout.win_id("detail")
	if win == nil or not vim.api.nvim_win_is_valid(win) then
		return nil
	end
	return win
end

---@param lnum integer
---@return boolean
local function is_history_line(lnum)
	local item = state.line_map[lnum]
	if item == nil then
		return false
	end
	return item.kind == "header"
		or item.kind == "content"
		or item.kind == "thread_header"
		or item.kind == "thread_content"
end

---@param win integer
---@param delta integer
---@return boolean
local function jump_next_history(win, delta)
	local line = vim.api.nvim_win_get_cursor(win)[1]
	local buf = vim.api.nvim_win_get_buf(win)
	local max_line = vim.api.nvim_buf_line_count(buf)
	local step = delta > 0 and 1 or -1

	for lnum = line + step, (step > 0 and max_line or 1), step do
		if is_history_line(lnum) then
			vim.api.nvim_win_set_cursor(win, { lnum, 0 })
			return true
		end
	end

	return false
end

local panel_spinner = spinner.create({
	interval_ms = 120,
	on_tick = function()
		if not state.is_loading then
			panel_spinner:stop()
			return
		end
		if panel_state.current_tab ~= "history" then
			return
		end
		require("atlas.jira.panel.init").refresh()
	end,
})

local function stop_spinner()
	panel_spinner:stop()
end

local function cancel_active_handle()
	if active_handle ~= nil and active_handle.cancel then
		pcall(active_handle.cancel)
	end
	active_handle = nil
end

local function start_spinner()
	if panel_spinner:is_running() then
		return
	end
	panel_spinner:start()
end

---@param entries JiraIssueHistoryEntry[]|nil
local function sort_history_entries(entries)
	if entries == nil then
		return
	end
	table.sort(entries, function(a, b)
		local ac = a.created or ""
		local bc = b.created or ""
		if ac == bc then
			return a.id < b.id
		end
		return ac > bc
	end)
end

---@param issue JiraIssue|nil
function M.show(issue)
	request_id = request_id + 1
	local current_request_id = request_id

	local prev_key = state.issue and state.issue.key or nil
	local next_key = issue and issue.key or nil
	local same_issue = prev_key == next_key

	if same_issue and state.is_loading then
		state.issue = issue
		state.line_map = {}
		start_spinner()
		require("atlas.jira.panel.init").refresh()
		return
	end

	cancel_active_handle()
	stop_spinner()
	state.issue = issue
	state.line_map = {}

	if issue == nil or issue.key == "" then
		state.history_items = nil
		state.is_loading = false
		return
	end

	if same_issue and state.history_items ~= nil and not state.is_loading then
		return
	end

	state.history_items = {}
	state.is_loading = true
	start_spinner()
	footer.notify("loading", string.format("Loading history for %s...", issue.key))
	require("atlas.jira.panel.init").refresh()

	local function fetch_page(start_at)
		active_handle = issues_api.get_issue_history_page(issue.key, start_at, 100, function(page, err)
			active_handle = nil

			if current_request_id ~= request_id then
				return
			end

			if err ~= nil or page == nil then
				state.is_loading = false
				stop_spinner()
				footer.notify("error", string.format("Failed loading history for %s", issue.key))
				require("atlas.jira.panel.init").refresh()
				return
			end

			if state.history_items == nil then
				state.history_items = {}
			end

			for _, entry in ipairs(page.values or {}) do
				table.insert(state.history_items, entry)
			end

			sort_history_entries(state.history_items)

			require("atlas.jira.panel.init").refresh()

			local next_start = page.start_at + page.max_results
			local done = page.is_last == true or next_start >= page.total

			if done then
				state.is_loading = false
				stop_spinner()
				footer.notify(
					"success",
					string.format("History loaded for %s (%d)", issue.key, #state.history_items),
					1200
				)
				require("atlas.jira.panel.init").refresh()
				return
			end

			fetch_page(next_start)
		end)
	end

	fetch_page(0)
end

function M.refresh()
	if state.issue == nil then
		return
	end

	state.history_items = nil
	state.is_loading = false
	M.show(state.issue)
end

---@param delta integer
function M.move(delta)
	if panel_state.current_tab ~= "history" then
		return
	end

	local win = detail_win()
	if win == nil then
		return
	end

	local buf = vim.api.nvim_win_get_buf(win)
	local max_line = vim.api.nvim_buf_line_count(buf)

	if delta == 0 then
		for lnum = 1, max_line do
			if is_history_line(lnum) then
				vim.api.nvim_win_set_cursor(win, { lnum, 0 })
				return
			end
		end
		return
	end

	if delta == math.huge then
		for lnum = max_line, 1, -1 do
			if is_history_line(lnum) then
				vim.api.nvim_win_set_cursor(win, { lnum, 0 })
				return
			end
		end
		return
	end

	if jump_next_history(win, delta) then
		return
	end

	local line = vim.api.nvim_win_get_cursor(win)[1]
	local step = delta > 0 and 1 or -1
	local target = math.max(1, math.min(max_line, line + step))
	vim.api.nvim_win_set_cursor(win, { target, 0 })
end

function M.reset()
	cancel_active_handle()
	stop_spinner()
	state.reset()
end

function M.deactivate()
	cancel_active_handle()
	state.is_loading = false
	stop_spinner()
end

function M.add_worklog() end

return M
