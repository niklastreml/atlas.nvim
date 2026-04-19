local M = {}

local layout = require("atlas.ui.layout")
local panel_state = require("atlas.pulls.ui.panel.pr.state")
local renderer = require("atlas.pulls.ui.panel.pr.renderer")
local icons = require("atlas.ui.shared.icons")

local SPINNER_INTERVAL_MS = 100

local DEFAULT_TABS = {
	{
		key = "overview",
		label = "Overview",
		icon = icons.general("overview"),
		mod = require("atlas.pulls.ui.panel.pr.tabs.overview"),
	},
}

--------------------------------------------------------------------------------
-- Loading spinner
--------------------------------------------------------------------------------

local spinner_timer = nil

local function stop_spinner()
	if spinner_timer ~= nil then
		spinner_timer:stop()
		spinner_timer:close()
		spinner_timer = nil
	end
end

local function is_loading()
	local pr = panel_state.current_pr
	if pr == nil then
		return false
	end
	local state = require("atlas.pulls.state")
	local provider = state.provider
	if provider and provider.panel and type(provider.panel.is_loading) == "function" then
		return provider.panel.is_loading(pr)
	end
	return false
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
			if not M.is_open() or not is_loading() then
				stop_spinner()
				return
			end
			M.render()
		end)
	)
end

local function update_spinner()
	if is_loading() then
		start_spinner()
	else
		stop_spinner()
	end
end

--------------------------------------------------------------------------------
-- Helper
--------------------------------------------------------------------------------

---@return PullsPanelTab[]
local function get_tabs()
	local state = require("atlas.pulls.state")
	local provider = state.provider
	if provider and provider.panel and provider.panel.tabs then
		local tabs = provider.panel.tabs()
		if type(tabs) == "table" and #tabs > 0 then
			return tabs
		end
	end
	return DEFAULT_TABS
end

---@param tab_key string
---@return PullsPanelTabModule|nil
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

---@return string
local function current_pr_key()
	local pr = panel_state.current_pr
	if pr == nil then
		return ""
	end
	return tostring(pr.repo_full_name or "") .. "/" .. tostring(pr.id or "")
end

---@return fun()
local function make_done()
	local key = current_pr_key()
	return function()
		if current_pr_key() ~= key then
			return
		end
		update_spinner()
		if M.is_open() then
			M.render()
		end
	end
end

---@param pr PullRequest
local function dispatch_provider_fetches(pr)
	local state = require("atlas.pulls.state")
	local provider = state.provider
	if provider and provider.panel and type(provider.panel.fetches) == "function" then
		provider.panel.fetches(pr, make_done())
	end
end

---@param pr PullRequest
---@param repo PullsRepo|nil
---@param opts { force_refresh: boolean|nil }|nil
local function notify_tab(pr, repo, opts)
	local tab_mod = get_tab_module(panel_state.current_tab)
	if tab_mod and type(tab_mod.on_select) == "function" then
		tab_mod.on_select(pr, repo, make_done(), opts)
	end
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

---@return boolean
function M.is_open()
	return layout.win_id("detail") ~= nil
end

function M.render()
	renderer.render(get_tabs(), get_tab_module)
end

---@param pr PullRequest|nil
---@param repo PullsRepo|nil
---@param opts { force_refresh: boolean|nil }|nil
function M.on_select(pr, repo, opts)
	opts = opts or {}

	local same_pr = pr ~= nil
		and panel_state.current_pr ~= nil
		and tostring(panel_state.current_pr.id) == tostring(pr.id)
		and tostring(panel_state.current_pr.repo_full_name) == tostring(pr.repo_full_name)

	if pr then
		panel_state.current_pr = pr
	end
	if repo then
		panel_state.current_repo = repo
	end

	if panel_state.current_pr == nil then
		return
	end

	activate_current_tab()

	local should_fetch = not same_pr or opts.force_refresh == true

	if not same_pr and pr ~= nil then
		local old_key = panel_state.current_tab
		if panel_state.current_tab == nil then
			panel_state.current_tab = get_tabs()[1].key
		end
		switch_tab_keymaps(old_key, panel_state.current_tab)
		stop_spinner()
	end

	if should_fetch then
		dispatch_provider_fetches(panel_state.current_pr)
		notify_tab(panel_state.current_pr, panel_state.current_repo, opts)
		update_spinner()
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

	if panel_state.current_pr then
		notify_tab(panel_state.current_pr, panel_state.current_repo)
		update_spinner()
	end

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

	if panel_state.current_pr then
		notify_tab(panel_state.current_pr, panel_state.current_repo)
		update_spinner()
	end

	M.render()
end

function M.close()
	switch_tab_keymaps(panel_state.current_tab, nil)
	stop_spinner()
	panel_state.reset()
end

function M.activate()
end

function M.deactivate()
	local tab_mod = get_tab_module(panel_state.current_tab)
	if tab_mod and type(tab_mod.deactivate) == "function" then
		tab_mod.deactivate()
	end
end

return M
