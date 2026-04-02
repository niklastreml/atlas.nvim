local M = {}
local state = require("atlas.jira.panel.tabs.history.state")
local panel_state = require("atlas.jira.panel.state")
local issues_api = require("atlas.jira.api.issues")
local spinner = require("atlas.ui.components.spinner")

local active_handle = nil
local request_id = 0

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
	require("atlas.jira.panel.init").refresh()

	local function fetch_page(start_at)
		active_handle = issues_api.get_issue_history_page(issue.key, start_at, 1, function(page, err)
			active_handle = nil

			if current_request_id ~= request_id then
				return
			end

			if panel_state.current_tab ~= "history" then
				return
			end

			if err ~= nil or page == nil then
				state.is_loading = false
				stop_spinner()
				require("atlas.jira.panel.init").refresh()
				return
			end

			if type(state.history_items) ~= "table" then
				state.history_items = {}
			end

			for _, entry in ipairs(page.values or {}) do
				table.insert(state.history_items, entry)
			end

			require("atlas.jira.panel.init").refresh()

			local next_start = (tonumber(page.start_at) or 0) + (tonumber(page.max_results) or 0)
			local done = page.is_last == true or next_start >= (tonumber(page.total) or 0)

			if done then
				state.is_loading = false
				stop_spinner()
				require("atlas.jira.panel.init").refresh()
				return
			end

			fetch_page(next_start)
		end)
	end

	fetch_page(0)
end

--- TODO: Add refresh keymap
function M.refresh()
	if state.issue == nil then
		return
	end

	state.history_items = nil
	state.is_loading = false
	M.show(state.issue)
end

function M.reset()
	cancel_active_handle()
	stop_spinner()
	state.reset()
end

function M.deactivate()
	cancel_active_handle()
	stop_spinner()
end

function M.add_worklog() end

return M
