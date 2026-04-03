local M = {}
local state = require("atlas.bitbucketv2.panel.tabs.repo.tags.state")
local panel_state = require("atlas.bitbucketv2.panel.state")
local repositories = require("atlas.bitbucketv2.api.repositories")
local spinner = require("atlas.ui.components.spinner")
local footer = require("atlas.ui.components.footer")

local tags_handle = nil

local panel_spinner = spinner.create({
	interval_ms = 120,
	on_tick = function()
		local tags_loading = panel_state.current_repo_tags == "loading"
		if not tags_loading then
			panel_spinner:stop()
			return
		end

		if panel_state.current_tab ~= "tags" then
			return
		end

		require("atlas.bitbucketv2.panel.init").refresh()
	end,
})

local function cancel_handles()
	if tags_handle ~= nil and tags_handle.cancel then
		pcall(tags_handle.cancel)
	end
	tags_handle = nil
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
	local prev_name = state.repo and state.repo.full_name or nil
	local next_name = repo and repo.full_name or nil
	local same_repo = prev_name == next_name

	if not same_repo then
		cancel_handles()
	end

	local tags_loading = panel_state.current_repo_tags == "loading"
	if same_repo and tags_loading then
		state.repo = repo
		state.line_map = {}
		start_spinner()
		require("atlas.bitbucketv2.panel.init").refresh()
		return
	end

	stop_spinner()
	state.repo = repo
	state.line_map = {}

	if repo == nil then
		panel_state.set_repo_tags(nil)
		return
	end

	if same_repo and panel_state.current_repo_tags ~= nil and panel_state.current_repo_tags ~= "loading" then
		return
	end

	local detail = panel_state.current_repo_detail
	if detail == nil or detail == "loading" then
		panel_state.set_repo_tags(nil)
		footer.notify("warn", "Repository detail not loaded yet")
		return
	end

	local tags_url = (detail.links and detail.links.tags and detail.links.tags.href) or ""
	if tags_url == "" then
		panel_state.set_repo_tags(nil)
		footer.notify("error", "Missing tags URL")
		return
	end

	-- Fetch tags
	panel_state.set_repo_tags_loading()
	start_spinner()

	tags_handle = repositories.fetch_tags(tags_url, {}, function(tags, err)
		tags_handle = nil

		if state.repo == nil or state.repo.full_name ~= next_name then
			return
		end

		if err ~= nil then
			panel_state.set_repo_tags(nil)
			footer.notify("error", "Failed to load tags: " .. tostring(err))
		else
			panel_state.set_repo_tags(tags)
			footer.notify("success", "Tags loaded", 1200)
		end

		stop_spinner()
		require("atlas.bitbucketv2.panel.init").refresh()
	end)

	footer.notify("loading", "Loading tags...")
	require("atlas.bitbucketv2.panel.init").refresh()
end

function M.refresh()
	if state.repo == nil then
		return
	end

	cancel_handles()
	panel_state.set_repo_tags(nil)
	M.show(state.repo)
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
	if panel_state.current_tab ~= "tags" then
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
