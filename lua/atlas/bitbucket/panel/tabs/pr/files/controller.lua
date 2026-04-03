local M = {}
local state = require("atlas.bitbucket.panel.tabs.pr.files.state")
local panel_state = require("atlas.bitbucket.panel.state")
local pullrequests = require("atlas.bitbucket.api.pullrequests")
local spinner = require("atlas.ui.components.spinner")
local footer = require("atlas.ui.components.footer")

local diffstat_handle = nil
local diff_handle = nil

local panel_spinner
panel_spinner = spinner.create({
	interval_ms = 120,
	on_tick = function()
		local diffstat_loading = state.diffstat == "loading"
		local diff_loading = state.diff == "loading"
		if not diffstat_loading and not diff_loading then
			panel_spinner:stop()
			return
		end

		if panel_state.current_tab ~= "files" then
			return
		end

		require("atlas.bitbucket.panel.init").refresh()
	end,
})

local function cancel_handles()
	if diffstat_handle ~= nil and diffstat_handle.cancel then
		pcall(diffstat_handle.cancel)
	end
	diffstat_handle = nil

	if diff_handle ~= nil and diff_handle.cancel then
		pcall(diff_handle.cancel)
	end
	diff_handle = nil
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
		cancel_handles()
	end

	local diffstat_loading = state.diffstat == "loading"
	local diff_loading = state.diff == "loading"
	if same_pr and (diffstat_loading or diff_loading) then
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
		state.diffstat = nil
		state.diff = nil
		return
	end

	if
		same_pr
		and state.diffstat ~= nil
		and state.diffstat ~= "loading"
		and state.diff ~= nil
		and state.diff ~= "loading"
	then
		return
	end

	local diffstat_url = (pr.links or {}).diffstat
	local diff_url = (pr.links or {}).diff

	if type(diffstat_url) ~= "string" or diffstat_url == "" then
		state.diffstat = nil
		footer.notify("error", "Missing diffstat URL")
	else
		state.diffstat = "loading"
		start_spinner()

		diffstat_handle = pullrequests.fetch_diffstat(diffstat_url, {}, function(diffstat, err)
			diffstat_handle = nil

			if state.pr == nil or state.pr.id ~= next_id then
				return
			end

			if err ~= nil then
				state.diffstat = nil
				footer.notify("error", "Failed to load diffstat: " .. tostring(err))
			else
				state.diffstat = diffstat
			end

			if state.diff ~= "loading" then
				stop_spinner()
				footer.notify("success", "Files loaded", 1200)
			end
			require("atlas.bitbucket.panel.init").refresh()
		end)
	end

	if type(diff_url) ~= "string" or diff_url == "" then
		state.diff = nil
		footer.notify("error", "Missing diff URL")
	else
		state.diff = "loading"
		start_spinner()

		diff_handle = pullrequests.fetch_diff(diff_url, function(diff, err)
			diff_handle = nil

			if state.pr == nil or state.pr.id ~= next_id then
				return
			end

			if err ~= nil then
				state.diff = nil
				footer.notify("error", "Failed to load diff: " .. tostring(err))
			else
				state.diff = diff
			end

			if state.diffstat ~= "loading" then
				stop_spinner()
				footer.notify("success", "Files loaded", 1200)
			end
			require("atlas.bitbucket.panel.init").refresh()
		end)
	end

	footer.notify("loading", "Loading file changes...")
	require("atlas.bitbucket.panel.init").refresh()
end

function M.refresh()
	if state.pr == nil then
		return
	end

	local pr = state.pr
	local diffstat_url = (pr.links or {}).diffstat
	local diff_url = (pr.links or {}).diff

	cancel_handles()
	state.diffstat = "loading"
	state.diff = "loading"
	start_spinner()
	require("atlas.bitbucket.panel.init").refresh()

	if type(diffstat_url) == "string" and diffstat_url ~= "" then
		diffstat_handle = pullrequests.fetch_diffstat(diffstat_url, { force_load = true }, function(diffstat, err)
			diffstat_handle = nil

			if state.pr == nil then
				return
			end

			if err ~= nil then
				state.diffstat = nil
			else
				state.diffstat = diffstat
			end

			if state.diff ~= "loading" then
				stop_spinner()
				footer.notify("success", "Files refreshed", 1200)
			end
			require("atlas.bitbucket.panel.init").refresh()
		end)
	end

	if type(diff_url) == "string" and diff_url ~= "" then
		diff_handle = pullrequests.fetch_diff(diff_url, function(diff, err)
			diff_handle = nil

			if state.pr == nil then
				return
			end

			if err ~= nil then
				state.diff = nil
			else
				state.diff = diff
			end

			if state.diffstat ~= "loading" then
				stop_spinner()
				footer.notify("success", "Files refreshed", 1200)
			end
			require("atlas.bitbucket.panel.init").refresh()
		end)
	end
end

function M.reset()
	cancel_handles()
	stop_spinner()
	state.reset()
end

function M.deactivate()
	stop_spinner()
end

---@param delta integer
function M.move(delta)
	if panel_state.current_tab ~= "files" then
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
