local M = {}
local state = require("atlas.jira.panel.tabs.worklogs.state")
local panel_state = require("atlas.jira.panel.state")
local spinner = require("atlas.ui.components.spinner")

local panel_spinner = spinner.create({
	interval_ms = 120,
	on_tick = function()
		if state.worklogs_text ~= "loading" then
			panel_spinner:stop()
			return
		end
		if panel_state.current_tab ~= "worklogs" then
			return
		end
		require("atlas.jira.panel.init").refresh()
	end,
})

local function stop_spinner()
	panel_spinner:stop()
end

local function start_spinner()
	if panel_spinner:is_running() then
		return
	end
	panel_spinner:start()
end

---@param issue JiraIssue|nil
function M.show(issue)
	local prev_key = state.issue and state.issue.key or nil
	local next_key = issue and issue.key or nil
	local same_issue = prev_key == next_key

	if same_issue and state.worklogs_text == "loading" then
		state.issue = issue
		state.line_map = {}
		start_spinner()
		require("atlas.jira.panel.init").refresh()
		return
	end

	stop_spinner()
	state.issue = issue
	state.line_map = {}

	if issue == nil or issue.key == "" then
		state.worklogs_text = nil
		return
	end

	if same_issue and state.worklogs_text ~= nil and state.worklogs_text ~= "loading" then
		return
	end

	state.worklogs_text = "loading"
	start_spinner()
	require("atlas.jira.panel.init").refresh()

	-- TODO: Fetch actual worklogs content and update state.worklogs_text
end

--- TODO: Add refresh keymap
function M.refresh() end

function M.reset()
	stop_spinner()
	state.reset()
end

function M.deactivate()
	stop_spinner()
end

function M.add_worklog() end

return M
