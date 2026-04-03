local M = {}
local tab_state = require("atlas.bitbucket.panel.tabs.repo.branches.state")
local state = require("atlas.bitbucket.panel.tabs.repo.state")
local panel_state = require("atlas.bitbucket.panel.state")
local repositories = require("atlas.bitbucket.api.repositories")
local spinner = require("atlas.ui.components.spinner")
local footer = require("atlas.ui.components.footer")

local branches_handle = nil

local panel_spinner
panel_spinner = spinner.create({
	interval_ms = 120,
	on_tick = function()
		local waiting_for_detail = state.detail == "loading"
		local branches_loading = tab_state.branches == "loading"
		if not waiting_for_detail and not branches_loading then
			panel_spinner:stop()
			return
		end

		if panel_state.current_tab ~= "branches" then
			return
		end

		if branches_handle == nil and tab_state.repo ~= nil and branches_loading and not waiting_for_detail then
			if type(state.detail) == "table" then
				M.show(tab_state.repo)
			else
				tab_state.branches = nil
				panel_spinner:stop()
			end
			return
		end

		require("atlas.bitbucket.panel.init").refresh()
	end,
})

local function cancel_handles()
	if branches_handle ~= nil and branches_handle.cancel then
		pcall(branches_handle.cancel)
	end
	branches_handle = nil
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

---@param repo table|nil
function M.show(repo)
	local prev_name = tab_state.repo and tab_state.repo.full_name or nil
	local next_name = repo and repo.full_name or nil
	local same_repo = prev_name == next_name

	if not same_repo then
		cancel_handles()
	end

	local branches_loading = tab_state.branches == "loading"
	if same_repo and branches_loading and (state.detail == "loading" or branches_handle ~= nil) then
		tab_state.repo = repo
		tab_state.line_map = {}
		start_spinner()
		require("atlas.bitbucket.panel.init").refresh()
		return
	end

	stop_spinner()
	tab_state.repo = repo
	tab_state.line_map = {}

	if repo == nil then
		tab_state.branches = nil
		return
	end

	-- If we already have branches for this repo, don't refetch
	if same_repo and tab_state.branches ~= nil and tab_state.branches ~= "loading" then
		return
	end

	-- We need the repo detail to get the branches URL
	local detail = state.detail
	if detail == "loading" then
		tab_state.branches = "loading"
		start_spinner()
		require("atlas.bitbucket.panel.init").refresh()
		return
	end

	if detail == nil then
		tab_state.branches = nil
		footer.notify("warn", "Repository detail not loaded yet")
		return
	end

	local branches_url = (detail.links and detail.links.branches and detail.links.branches.href) or ""
	if branches_url == "" then
		tab_state.branches = nil
		footer.notify("error", "Missing branches URL")
		return
	end

	tab_state.branches = "loading"
	start_spinner()

	branches_handle = repositories.fetch_branches(branches_url, {}, function(branches, err)
		branches_handle = nil

		if tab_state.repo == nil or tab_state.repo.full_name ~= next_name then
			return
		end

		if err ~= nil then
			tab_state.branches = nil
			footer.notify("error", "Failed to load branches: " .. tostring(err))
		else
			tab_state.branches = branches
			footer.notify("success", "Branches loaded", 1200)
		end

		stop_spinner()
		require("atlas.bitbucket.panel.init").refresh()
	end)

	footer.notify("loading", "Loading branches...")
	require("atlas.bitbucket.panel.init").refresh()
end

function M.refresh()
	if tab_state.repo == nil then
		return
	end

	cancel_handles()
	tab_state.branches = nil
	M.show(tab_state.repo)
end

function M.reset()
	cancel_handles()
	stop_spinner()
	tab_state.reset()
end

function M.deactivate()
	stop_spinner()
end

---@param delta integer
function M.move(delta)
	if panel_state.current_tab ~= "branches" then
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
