local M = {}

local layout = require("atlas.ui.layout")
local panel_state = require("atlas.pulls.ui.panel.repo.state")
local renderer = require("atlas.pulls.ui.panel.repo.renderer")
local icons = require("atlas.ui.shared.icons")

local DEFAULT_TABS = {
	{
		key = "overview",
		label = "Overview",
		icon = icons.general("overview"),
		mod = require("atlas.pulls.ui.panel.repo.tabs.overview"),
	},
	{
		key = "branches",
		label = "Branches",
		icon = icons.pulls("branch"),
		mod = require("atlas.pulls.ui.panel.repo.tabs.branches"),
	},
	{
		key = "tags",
		label = "Tags",
		icon = icons.general("tag"),
		mod = require("atlas.pulls.ui.panel.repo.tabs.tags"),
	},
}

local SPINNER_INTERVAL_MS = 100
local spinner_timer = nil
local detail_request = nil

local function stop_spinner()
	if spinner_timer ~= nil then
		spinner_timer:stop()
		spinner_timer:close()
		spinner_timer = nil
	end
end

local function start_spinner()
	if spinner_timer ~= nil then
		return
	end
	spinner_timer = vim.loop.new_timer()
	if spinner_timer == nil then
		return
	end
	spinner_timer:start(
		SPINNER_INTERVAL_MS,
		SPINNER_INTERVAL_MS,
		vim.schedule_wrap(function()
			if not M.is_open() or not panel_state.loading_details then
				stop_spinner()
				return
			end
			M.render()
		end)
	)
end

local function update_spinner()
	if panel_state.loading_details then
		start_spinner()
	else
		stop_spinner()
	end
end

local function stop_request()
	if detail_request ~= nil and type(detail_request.cancel) == "function" then
		detail_request.cancel()
	end
	detail_request = nil
end

---@return PullsRepoPanelTab[]
local function get_tabs()
	local state = require("atlas.pulls.state")
	local provider = state.provider
	if provider and provider.repo_panel and provider.repo_panel.tabs then
		local tabs = provider.repo_panel.tabs()
		if type(tabs) == "table" and #tabs > 0 then
			return tabs
		end
	end
	return DEFAULT_TABS
end

---@param tab_key string
---@return PullsRepoPanelTabModule|nil
local function get_tab_module(tab_key)
	for _, tab in ipairs(get_tabs()) do
		if tab.key == tab_key then
			return tab.mod
		end
	end
	return nil
end

local function cursor_entry()
	local win = layout.win_id("detail")
	if win == nil or not vim.api.nvim_win_is_valid(win) then
		return nil
	end
	local lnum = vim.api.nvim_win_get_cursor(win)[1]
	return (panel_state.line_map or {})[lnum]
end

local function done()
	if M.is_open() then
		M.render()
	end
end

local function activate_current_tab()
	local tab_mod = get_tab_module(panel_state.current_tab)
	if tab_mod and type(tab_mod.activate) == "function" then
		tab_mod.activate()
	end
end

---@param old_key string|nil
---@param new_key string|nil
local function switch_tab_keymaps(old_key, new_key)
	local buf = layout.buf_id("detail")
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	if old_key then
		local old_mod = get_tab_module(old_key)
		if old_mod and type(old_mod.deactivate) == "function" and old_key ~= new_key then
			old_mod.deactivate()
		end
		if old_mod and type(old_mod.teardown_keymaps) == "function" then
			old_mod.teardown_keymaps(buf)
		end
	end
	if new_key then
		local new_mod = get_tab_module(new_key)
		if new_mod and type(new_mod.activate) == "function" and old_key ~= new_key then
			new_mod.activate()
		end
		if new_mod and type(new_mod.setup_keymaps) == "function" then
			new_mod.setup_keymaps(buf, cursor_entry, done)
		end
	end
end

---@param repo PullsRepo
---@param opts { force_refresh: boolean|nil }|nil
local function notify_tab(repo, opts)
	local tab_mod = get_tab_module(panel_state.current_tab)
	if tab_mod and type(tab_mod.on_select) == "function" then
		tab_mod.on_select(nil, repo, done, opts)
	end
end

function M.is_open()
	return layout.win_id("detail") ~= nil
end

function M.render()
	renderer.render(get_tabs(), get_tab_module)
end

---@param repo PullsRepo|nil
---@param opts { force_refresh: boolean|nil }|nil
function M.on_select(repo, opts)
	opts = opts or {}
	local state = require("atlas.pulls.state")
	local provider = state.provider
	local same_repo = repo ~= nil
		and panel_state.current_repo ~= nil
		and tostring(panel_state.current_repo.id) == tostring(repo.id)
	if repo then
		if not same_repo then
			panel_state.current_repo_details = nil
		end
		panel_state.current_repo = repo
	end
	if panel_state.current_repo == nil then
		return
	end
	if panel_state.current_tab == nil then
		panel_state.current_tab = get_tabs()[1].key
	end

	activate_current_tab()

	local should_fetch = opts.force_refresh == true or panel_state.current_repo_details == nil
	if provider and type(provider.fetch_repo_details) == "function" and should_fetch then
		local repo_key = tostring(panel_state.current_repo.id or "")
		stop_request()
		panel_state.loading_details = true
		update_spinner()
		detail_request = provider.fetch_repo_details(panel_state.current_repo, {
			force_load = opts.force_refresh == true,
		}, function(details, err)
			detail_request = nil
			if panel_state.current_repo == nil or tostring(panel_state.current_repo.id or "") ~= repo_key then
				return
			end
			panel_state.loading_details = false
			if err == nil and details ~= nil then
				panel_state.current_repo_details = details
			end
			update_spinner()
			if M.is_open() then
				M.render()
			end
		end)
	else
		panel_state.loading_details = false
		update_spinner()
	end

	if opts.force_refresh == true then
		notify_tab(panel_state.current_repo, opts)
	end
	if M.is_open() then
		M.render()
	end
end

function M.next_tab()
	local tabs = get_tabs()
	local old_key = panel_state.current_tab
	local idx = 1
	for i, tab in ipairs(tabs) do
		if tab.key == old_key then
			idx = i
			break
		end
	end
	local next_idx = idx + 1
	if next_idx > #tabs then
		next_idx = 1
	end
	panel_state.current_tab = tabs[next_idx].key
	switch_tab_keymaps(old_key, panel_state.current_tab)
	M.render()
end

function M.prev_tab()
	local tabs = get_tabs()
	local old_key = panel_state.current_tab
	local idx = 1
	for i, tab in ipairs(tabs) do
		if tab.key == old_key then
			idx = i
			break
		end
	end
	local prev_idx = idx - 1
	if prev_idx < 1 then
		prev_idx = #tabs
	end
	panel_state.current_tab = tabs[prev_idx].key
	switch_tab_keymaps(old_key, panel_state.current_tab)
	M.render()
end

function M.close()
	switch_tab_keymaps(panel_state.current_tab, nil)
	stop_request()
	stop_spinner()
	panel_state.reset()
end

function M.activate()
end

function M.deactivate()
	stop_request()
	stop_spinner()

	local tab_mod = get_tab_module(panel_state.current_tab)
	if tab_mod and type(tab_mod.deactivate) == "function" then
		tab_mod.deactivate()
	end
end

return M
