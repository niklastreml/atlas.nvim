local M = {}

local layout = require("atlas.ui.layout")
local panel_state = require("atlas.pulls.ui.panel.state")
local renderer = require("atlas.pulls.ui.panel.renderer")
local icons = require("atlas.shared.icons")

local SPINNER_INTERVAL_MS = 100

local DEFAULT_TABS = {
	{ key = "overview", label = "Overview", icon = icons.general("overview"), mod = require("atlas.pulls.ui.panel.tabs.overview") },
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
	if provider and type(provider.panel_is_loading) == "function" then
		return provider.panel_is_loading(pr)
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
	spinner_timer:start(SPINNER_INTERVAL_MS, SPINNER_INTERVAL_MS, vim.schedule_wrap(function()
		if not M.is_open() or not is_loading() then
			stop_spinner()
			return
		end
		M.render()
	end))
end

local function update_spinner()
	if is_loading() then
		start_spinner()
	else
		stop_spinner()
	end
end

--------------------------------------------------------------------------------
-- Tabs
--------------------------------------------------------------------------------

---@return PullsPanelTab[]
local function get_tabs()
	local state = require("atlas.pulls.state")
	local provider = state.provider
	if provider and provider.panel_tabs then
		local tabs = provider.panel_tabs()
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

--------------------------------------------------------------------------------
-- Fetch lifecycle
--------------------------------------------------------------------------------

---@return string
local function current_pr_key()
	local pr = panel_state.current_pr
	if pr == nil then
		return ""
	end
	return tostring(pr.repo_id or "") .. "/" .. tostring(pr.id or "")
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
	if provider and type(provider.panel_fetches) == "function" then
		provider.panel_fetches(pr, make_done())
	end
end

---@param pr PullRequest
---@param repo PullsRepo|nil
local function notify_tab(pr, repo)
	local tab_mod = get_tab_module(panel_state.current_tab)
	if tab_mod and type(tab_mod.on_select) == "function" then
		tab_mod.on_select(pr, repo, make_done())
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
function M.on_select(pr, repo)
	if pr == nil then
		return
	end

	local same_pr = panel_state.current_pr ~= nil
		and tostring(panel_state.current_pr.id) == tostring(pr.id)
		and tostring(panel_state.current_pr.repo_id) == tostring(pr.repo_id)

	panel_state.current_pr = pr
	panel_state.current_repo = repo

	if not same_pr then
		if panel_state.current_tab == nil then
			panel_state.current_tab = get_tabs()[1].key
		end
		stop_spinner()
		dispatch_provider_fetches(pr)
		notify_tab(pr, repo)
		update_spinner()
	end

	if M.is_open() then
		M.render()
	end
end

function M.next_tab()
	local tabs = get_tabs()
	local idx = 1
	for i, tab in ipairs(tabs) do
		if tab.key == panel_state.current_tab then
			idx = i
			break
		end
	end

	local next_idx = idx + 1
	if next_idx > #tabs then
		next_idx = 1
	end

	panel_state.current_tab = tabs[next_idx].key

	if panel_state.current_pr then
		notify_tab(panel_state.current_pr, panel_state.current_repo)
		update_spinner()
	end

	M.render()
end

function M.prev_tab()
	local tabs = get_tabs()
	local idx = 1
	for i, tab in ipairs(tabs) do
		if tab.key == panel_state.current_tab then
			idx = i
			break
		end
	end

	local prev_idx = idx - 1
	if prev_idx < 1 then
		prev_idx = #tabs
	end

	panel_state.current_tab = tabs[prev_idx].key

	if panel_state.current_pr then
		notify_tab(panel_state.current_pr, panel_state.current_repo)
		update_spinner()
	end

	M.render()
end

function M.close()
	stop_spinner()
	panel_state.reset()
end

return M
