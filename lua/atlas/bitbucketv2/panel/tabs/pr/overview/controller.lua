local M = {}
local state = require("atlas.bitbucketv2.panel.tabs.pr.overview.state")
local panel_state = require("atlas.bitbucketv2.panel.state")
local pullrequests = require("atlas.bitbucketv2.api.pullrequests")
local spinner = require("atlas.ui.components.spinner")
local footer = require("atlas.ui.components.footer")

local active_handle = nil

local panel_spinner = spinner.create({
	interval_ms = 120,
	on_tick = function()
		if panel_state.current_pr_detail ~= "loading" then
			panel_spinner:stop()
			return
		end

		if panel_state.current_tab ~= "overview" then
			return
		end

		require("atlas.bitbucketv2.panel.init").refresh()
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

---@param pr BitbucketPR|nil
function M.show(pr)
	local prev_id = state.pr and state.pr.id or nil
	local next_id = pr and pr.id or nil
	local same_pr = prev_id == next_id

	if not same_pr then
		cancel_active_handle()
	end

	if same_pr and panel_state.current_pr_detail == "loading" then
		state.pr = pr
		state.line_map = {}
		start_spinner()
		require("atlas.bitbucketv2.panel.init").refresh()
		return
	end

	stop_spinner()
	state.pr = pr
	state.line_map = {}

	if pr == nil then
		panel_state.set_pr_detail(nil)
		return
	end

	if same_pr and panel_state.current_pr_detail ~= nil and panel_state.current_pr_detail ~= "loading" then
		return
	end

	local repo = pr.repo or {}
	local workspace = tostring(repo.workspace or "")
	local repo_slug = tostring(repo.repo or "")
	local pr_id = tostring(pr.id or "")

	if workspace == "" or repo_slug == "" or pr_id == "" then
		panel_state.set_pr_detail(nil)
		footer.notify("error", "Missing PR info for detail fetch")
		return
	end

	panel_state.set_pr_detail_loading()
	start_spinner()
	footer.notify("loading", string.format("Loading PR #%s...", pr_id))
	require("atlas.bitbucketv2.panel.init").refresh()

	active_handle = pullrequests.fetch_detail(workspace, repo_slug, pr_id, {}, function(detail, err)
		active_handle = nil

		if state.pr == nil or tostring(state.pr.id) ~= pr_id then
			return
		end

		if err ~= nil then
			panel_state.set_pr_detail(nil)
			footer.notify("error", string.format("Failed to load PR #%s: %s", pr_id, tostring(err)))
		else
			panel_state.set_pr_detail(detail)
			footer.notify("success", string.format("PR #%s loaded", pr_id), 1200)
		end

		stop_spinner()
		require("atlas.bitbucketv2.panel.init").refresh()
	end)
end

function M.refresh()
	if state.pr == nil then
		return
	end

	local pr = state.pr
	local repo = pr.repo or {}
	local workspace = tostring(repo.workspace or "")
	local repo_slug = tostring(repo.repo or "")
	local pr_id = tostring(pr.id or "")

	if workspace == "" or repo_slug == "" or pr_id == "" then
		return
	end

	cancel_active_handle()
	panel_state.set_pr_detail_loading()
	start_spinner()
	require("atlas.bitbucketv2.panel.init").refresh()

	active_handle = pullrequests.fetch_detail(workspace, repo_slug, pr_id, { force_load = true }, function(detail, err)
		active_handle = nil

		if state.pr == nil or tostring(state.pr.id) ~= pr_id then
			return
		end

		if err ~= nil then
			panel_state.set_pr_detail(nil)
			footer.notify("error", string.format("Failed to refresh PR #%s", pr_id))
		else
			panel_state.set_pr_detail(detail)
			footer.notify("success", string.format("PR #%s refreshed", pr_id), 1200)
		end

		stop_spinner()
		require("atlas.bitbucketv2.panel.init").refresh()
	end)
end

function M.reset()
	cancel_active_handle()
	stop_spinner()
	state.reset()
end

function M.deactivate()
	stop_spinner()
end

---@param delta integer
function M.move(delta)
	if panel_state.current_tab ~= "overview" then
		return
	end

	local layout = require("atlas.ui.layout")
	local win = layout.win_id("detail")
	if win == nil or not vim.api.nvim_win_is_valid(win) then
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

return M
