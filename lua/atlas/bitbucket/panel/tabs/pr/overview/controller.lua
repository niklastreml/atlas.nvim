local M = {}
local state = require("atlas.bitbucket.panel.tabs.pr.overview.state")
local panel_state = require("atlas.bitbucket.panel.state")
local pullrequests = require("atlas.bitbucket.api.pullrequests")
local spinner = require("atlas.ui.components.spinner")
local footer = require("atlas.ui.components.footer")

local active_handle = nil
local diffstat_handle = nil

local panel_spinner
panel_spinner = spinner.create({
	interval_ms = 120,
	on_tick = function()
		if state.detail ~= "loading" and state.diffstat ~= "loading" then
			panel_spinner:stop()
			return
		end

		if panel_state.current_tab ~= "overview" then
			return
		end

		require("atlas.bitbucket.panel.init").refresh()
	end,
})

local function cancel_active_handle()
	if active_handle ~= nil and active_handle.cancel then
		pcall(active_handle.cancel)
	end
	active_handle = nil

	if diffstat_handle ~= nil and diffstat_handle.cancel then
		pcall(diffstat_handle.cancel)
	end
	diffstat_handle = nil
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

	local detail_loading = state.detail == "loading"
	local diffstat_loading = state.diffstat == "loading"

	if same_pr and (detail_loading or diffstat_loading) then
		state.pr = pr
		state.line_map = {}
		start_spinner()
		require("atlas.bitbucket.panel.init").refresh()
		return
	end

	stop_spinner()
	state.pr = pr
	state.line_map = {}

	if pr == nil then
		state.detail = nil
		state.diffstat = nil
		return
	end

	local workspace = pr.workspace
	local repo_slug = pr.repo
	local pr_id = tostring(pr.id)

	if workspace == "" or repo_slug == "" or pr_id == "" then
		state.detail = nil
		state.diffstat = nil
		footer.notify("error", "Missing PR info for detail fetch")
		return
	end

	local needs_detail = not (same_pr and state.detail ~= nil and state.detail ~= "loading")
	local needs_diffstat = not (same_pr and state.diffstat ~= nil and state.diffstat ~= "loading")

	if not needs_detail and not needs_diffstat then
		return
	end

	start_spinner()
	footer.notify("loading", string.format("Loading PR #%s...", pr_id))
	require("atlas.bitbucket.panel.init").refresh()

	if needs_detail then
		state.detail = "loading"

		active_handle = pullrequests.fetch_pullrequest(workspace, repo_slug, pr_id, function(detail, err)
			active_handle = nil

			if state.pr == nil or tostring(state.pr.id) ~= pr_id then
				return
			end

			if err ~= nil then
				state.detail = nil
				footer.notify("error", string.format("Failed to load PR #%s: %s", pr_id, tostring(err)))
			else
				state.detail = detail
			end

			if state.diffstat ~= "loading" then
				stop_spinner()
				footer.notify("success", string.format("PR #%s loaded", pr_id), 1200)
			end

			require("atlas.bitbucket.panel.init").refresh()
		end)
	end

	if needs_diffstat then
		local diffstat_url = pr.links.diffstat
		if diffstat_url ~= "" then
			state.diffstat = "loading"

			diffstat_handle = pullrequests.fetch_diffstat(diffstat_url, {}, function(diffstat, err)
				diffstat_handle = nil

				if state.pr == nil or tostring(state.pr.id) ~= pr_id then
					return
				end

				if err ~= nil then
					state.diffstat = nil
				else
					state.diffstat = diffstat
				end

				if state.detail ~= "loading" then
					stop_spinner()
					footer.notify("success", string.format("PR #%s loaded", pr_id), 1200)
				end

				require("atlas.bitbucket.panel.init").refresh()
			end)
		else
			state.diffstat = nil
		end
	end
end

function M.refresh()
	local pr = state.pr
	if pr == nil then
		return
	end

	local workspace = pr.workspace
	local repo_slug = pr.repo
	local pr_id = tostring(pr.id)

	if workspace == "" or repo_slug == "" or pr_id == "" then
		return
	end

	cancel_active_handle()
	state.detail = "loading"
	state.diffstat = "loading"
	start_spinner()
	require("atlas.bitbucket.panel.init").refresh()

	active_handle = pullrequests.fetch_pullrequest(workspace, repo_slug, pr_id, function(detail, err)
		active_handle = nil

		if state.pr == nil or tostring(state.pr.id) ~= pr_id then
			return
		end

		if err ~= nil then
			state.detail = nil
			footer.notify("error", string.format("Failed to refresh PR #%s", pr_id))
		else
			state.detail = detail
		end

		if state.diffstat ~= "loading" then
			stop_spinner()
			footer.notify("success", string.format("PR #%s refreshed", pr_id), 1200)
		end

		require("atlas.bitbucket.panel.init").refresh()
	end)

	local diffstat_url = pr.links.diffstat
	if diffstat_url ~= "" then
		diffstat_handle = pullrequests.fetch_diffstat(diffstat_url, { force_load = true }, function(diffstat, err)
			diffstat_handle = nil

			if state.pr == nil or tostring(state.pr.id) ~= pr_id then
				return
			end

			if err ~= nil then
				state.diffstat = nil
			else
				state.diffstat = diffstat
			end

			if state.detail ~= "loading" then
				stop_spinner()
				footer.notify("success", string.format("PR #%s refreshed", pr_id), 1200)
			end

			require("atlas.bitbucket.panel.init").refresh()
		end)
	else
		state.diffstat = nil
	end
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
