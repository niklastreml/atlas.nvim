local M = {}
local state = require("atlas.jira.panel.tabs.overview.state")
local panel_state = require("atlas.jira.panel.state")
local jira_actions = require("atlas.jira.actions")
local issues = require("atlas.jira.api.issues")
local adf = require("atlas.jira.converted.adf")
local spinner = require("atlas.ui.components.spinner")
local footer = require("atlas.ui.components.footer")

local active_handle = nil

---@return integer|nil
local function detail_win()
	local layout = require("atlas.ui.layout")
	local win = layout.win_id("detail")
	if win == nil or not vim.api.nvim_win_is_valid(win) then
		return nil
	end
	return win
end

local panel_spinner = spinner.create({
	interval_ms = 120,
	on_tick = function()
		if state.md_description ~= "loading" then
			panel_spinner:stop()
			return
		end

		if panel_state.current_tab ~= "overview" then
			return
		end

		require("atlas.jira.panel.init").refresh()
	end,
})

local function cancel_active_handle()
	if active_handle ~= nil and active_handle.cancel then
		pcall(active_handle.cancel)
	end
	active_handle = nil
end

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

	if not same_issue then
		cancel_active_handle()
	end

	if same_issue and state.md_description == "loading" then
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
		state.adf_description = nil
		state.md_description = nil
		return
	end

	if same_issue and state.md_description ~= nil and state.md_description ~= "loading" then
		return
	end

	local issue_key = issue.key
	state.adf_description = "loading"
	state.md_description = "loading"
	start_spinner()
	footer.notify("loading", string.format("Loading description for %s...", issue_key))
	require("atlas.jira.panel.init").refresh()

	active_handle = issues.get_issue_description(issue_key, function(description, err)
		active_handle = nil
		if state.issue == nil or state.issue.key ~= issue_key then
			return
		end

		if err ~= nil then
			state.adf_description = nil
			state.md_description = nil
			footer.notify("error", string.format("Failed loading description for %s", issue_key))
		else
			if type(description) == "table" then
				state.adf_description = description
				local markdown = adf.to_markdown(description)
				-- Keep empty string to mark "loaded but empty" and avoid refetch loops.
				state.md_description = markdown
			else
				-- Jira returns `description = null` for empty descriptions.
				-- Treat this as loaded-empty so we do not refetch on every tab switch.
				state.adf_description = nil
				state.md_description = ""
			end
			footer.notify("success", string.format("Description loaded for %s", issue_key), 1200)
		end

		stop_spinner()
		require("atlas.jira.panel.init").refresh()
	end)
end

function M.toggle_view_mode()
	if state.view_mode == "raw" then
		state.view_mode = "markdown"
		footer.notify("info", "Overview: Markdown view", 1000)
	else
		state.view_mode = "raw"
		footer.notify("info", "Overview: Raw ADF view", 1000)
	end

	require("atlas.jira.panel.init").refresh()
end

---@param delta integer
function M.move(delta)
	if panel_state.current_tab ~= "overview" then
		return
	end

	local win = detail_win()
	if win == nil then
		return
	end

	local buf = vim.api.nvim_win_get_buf(win)
	local max_line = vim.api.nvim_buf_line_count(buf)

	if delta == 0 then
		vim.api.nvim_win_set_cursor(win, { 1, 0 })
		return
	end

	if delta == math.huge then
		vim.api.nvim_win_set_cursor(win, { max_line, 0 })
		return
	end

	local line = vim.api.nvim_win_get_cursor(win)[1]
	local step = delta > 0 and 1 or -1
	local target = math.max(1, math.min(max_line, line + step))
	vim.api.nvim_win_set_cursor(win, { target, 0 })
end

function M.refresh()
	if state.issue == nil then
		return
	end

	cancel_active_handle()
	stop_spinner()
	state.adf_description = nil
	state.md_description = nil
	M.show(state.issue)
end

function M.reset()
	cancel_active_handle()
	stop_spinner()
	state.reset()
end

function M.deactivate()
	-- Keep in-flight requests alive across tab switches so data is warm on return.
	-- But stop local spinner ticks while tab is inactive.
	stop_spinner()
end

return M
