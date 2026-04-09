local M = {}
local tab_state = require("atlas.bitbucket.panel.tabs.repo.tags.state")
local state = require("atlas.bitbucket.panel.tabs.repo.state")
local panel_state = require("atlas.bitbucket.panel.state")
local repositories = require("atlas.bitbucket.api.repositories")
local spinner = require("atlas.ui.components.spinner")
local footer = require("atlas.ui.components.footer")

local tags_handle = nil

local panel_spinner
panel_spinner = spinner.create({
	interval_ms = 120,
	on_tick = function()
		local waiting_for_detail = state.detail == "loading"
		local tags_loading = tab_state.tags == "loading"
		if not waiting_for_detail and not tags_loading then
			panel_spinner:stop()
			return
		end

		if panel_state.current_tab ~= "tags" then
			return
		end

		if tags_handle == nil and tab_state.repo ~= nil and tags_loading and not waiting_for_detail then
			if state.detail ~= nil and state.detail ~= "loading" then
				M.show(tab_state.repo)
			else
				tab_state.tags = nil
				panel_spinner:stop()
			end
			return
		end

		require("atlas.bitbucket.panel.init").refresh()
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

---@param repo BitbucketRepository|nil
function M.show(repo)
	local prev_name = tab_state.repo and tab_state.repo.full_name or nil
	local next_name = repo and repo.full_name or nil
	local same_repo = prev_name == next_name

	if not same_repo then
		cancel_handles()
	end

	local tags_loading = tab_state.tags == "loading"
	if same_repo and tags_loading and (state.detail == "loading" or tags_handle ~= nil) then
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
		tab_state.tags = nil
		return
	end

	if same_repo and tab_state.tags ~= nil and tab_state.tags ~= "loading" then
		return
	end

	local detail = state.detail
	if detail == "loading" then
		tab_state.tags = "loading"
		start_spinner()
		require("atlas.bitbucket.panel.init").refresh()
		return
	end

	if detail == nil then
		tab_state.tags = nil
		footer.notify("warn", "Repository detail not loaded yet")
		return
	end

	local tags_url = detail.links.tags
	if tags_url == "" then
		tab_state.tags = nil
		footer.notify("error", "Missing tags URL")
		return
	end

	-- Fetch tags
	tab_state.tags = "loading"
	start_spinner()

	tags_handle = repositories.fetch_tags(tags_url, {}, function(tags, err)
		tags_handle = nil

		if tab_state.repo == nil or tab_state.repo.full_name ~= next_name then
			return
		end

		if err ~= nil then
			tab_state.tags = nil
			footer.notify("error", "Failed to load tags: " .. tostring(err))
		else
			tab_state.tags = tags
			footer.notify("success", "Tags loaded", 1200)
		end

		stop_spinner()
		require("atlas.bitbucket.panel.init").refresh()
	end)

	footer.notify("loading", "Loading tags...")
	require("atlas.bitbucket.panel.init").refresh()
end

function M.refresh()
	if tab_state.repo == nil then
		return
	end

	cancel_handles()
	tab_state.tags = nil
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
