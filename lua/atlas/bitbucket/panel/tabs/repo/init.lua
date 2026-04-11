local M = {}
local repo_state = require("atlas.bitbucket.panel.tabs.repo.state")
local repositories = require("atlas.bitbucket.api.repositories")

local TABS = {
	{ key = "overview", label = "Overview", mod = "atlas.bitbucket.panel.tabs.repo.overview" },
	{ key = "branches", label = "Branches", mod = "atlas.bitbucket.panel.tabs.repo.branches" },
	{ key = "tags", label = "Tags", mod = "atlas.bitbucket.panel.tabs.repo.tags" },
}

local detail_handle = nil
local detail_key = nil

---@param tab_key string
---@return string
local function next_tab_key(tab_key)
	local idx = 1
	for i, tab in ipairs(TABS) do
		if tab.key == tab_key then
			idx = i
			break
		end
	end
	local next_idx = idx + 1
	if next_idx > #TABS then
		next_idx = 1
	end
	return TABS[next_idx].key
end

---@param tab_key string
---@return string
local function prev_tab_key(tab_key)
	local idx = 1
	for i, tab in ipairs(TABS) do
		if tab.key == tab_key then
			idx = i
			break
		end
	end
	local prev_idx = idx - 1
	if prev_idx < 1 then
		prev_idx = #TABS
	end
	return TABS[prev_idx].key
end

---@param tab_key string
---@return table|nil
local function resolve_tab_module(tab_key)
	if tab_key == nil or tab_key == "" then
		return nil
	end

	for _, tab in ipairs(TABS) do
		if tab.key == tab_key then
			local ok, mod = pcall(require, tab.mod)
			if ok then
				return mod
			end
			return nil
		end
	end
	return nil
end

---@return string
local function active_tab_key()
	return repo_state.tab or "overview"
end

local function cancel_detail_request()
	if detail_handle ~= nil and detail_handle.cancel then
		pcall(detail_handle.cancel)
	end
	detail_handle = nil
end

local function clear_detail()
	cancel_detail_request()
	detail_key = nil
	repo_state.detail = nil
end

---@param force boolean
local function fetch_detail(force)
	local repo = repo_state.item
	if repo == nil then
		clear_detail()
		return
	end

	local key = tostring(repo.full_name or "")
	local workspace = tostring(repo.workspace or "")
	local repo_slug = tostring(repo.slug or "")
	if key == "" or workspace == "" or repo_slug == "" then
		repo_state.detail = nil
		return
	end

	if not force and detail_key == key and repo_state.detail ~= nil and repo_state.detail ~= "loading" then
		return
	end
	if not force and detail_key == key and repo_state.detail == "loading" then
		return
	end

	cancel_detail_request()
	detail_key = key
	repo_state.detail = "loading"

	detail_handle = repositories.fetch_detail(workspace, repo_slug, {
		force_load = force == true,
	}, function(detail, err)
		detail_handle = nil

		if repo_state.item == nil or tostring(repo_state.item.full_name or "") ~= key then
			return
		end

		if err ~= nil or detail == nil then
			repo_state.detail = nil
		else
			repo_state.detail = detail
		end

		local tab = resolve_tab_module(active_tab_key())
		if tab ~= nil and type(tab.refresh) == "function" then
			tab.refresh()
		end
	end)
end

---@param tab_key string
local function activate_tab(tab_key)
	local tab = resolve_tab_module(tab_key)
	if tab ~= nil and type(tab.activate) == "function" then
		tab.activate(repo_state.item)
	end
end

---@param tab_key string
local function deactivate_tab(tab_key)
	local tab = resolve_tab_module(tab_key)
	if tab ~= nil and type(tab.deactivate) == "function" then
		tab.deactivate()
	end
end

---@param tab_key string
local function select_tab(tab_key)
	deactivate_tab(repo_state.tab)
	repo_state.tab = tab_key
	activate_tab(tab_key)
	M.move(0)
end

---@param width integer
---@return string[], table[], table|nil
function M.render(width)
	local tab_key = active_tab_key()
	local tab = resolve_tab_module(tab_key)

	if tab ~= nil and type(tab.render) == "function" then
		return tab.render(width)
	end
	return {}, {}, nil
end

---@return boolean
function M.is_loading()
	if repo_state.detail == "loading" then
		return true
	end

	local tab_key = active_tab_key()
	local tab = resolve_tab_module(tab_key)
	return tab ~= nil and type(tab.is_loading) == "function" and tab.is_loading() == true
end

---@param delta integer
function M.move(delta)
	local tab = resolve_tab_module(active_tab_key())
	if tab == nil then
		return
	end

	local layout = require("atlas.ui.layout")
	local win = layout.win_id("detail")
	if win == nil or not vim.api.nvim_win_is_valid(win) then
		return
	end

	local buf = vim.api.nvim_win_get_buf(win)
	local max_line = vim.api.nvim_buf_line_count(buf)
	if max_line <= 0 then
		return
	end

	local is_selectable_line = tab.is_selectable_line
	if type(is_selectable_line) ~= "function" then
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
		return
	end

	if delta == 0 then
		for lnum = 1, max_line do
			if is_selectable_line(lnum) == true then
				vim.api.nvim_win_set_cursor(win, { lnum, 0 })
				return
			end
		end
		return
	end

	if delta == math.huge then
		for lnum = max_line, 1, -1 do
			if is_selectable_line(lnum) == true then
				vim.api.nvim_win_set_cursor(win, { lnum, 0 })
				return
			end
		end
		return
	end

	local line = vim.api.nvim_win_get_cursor(win)[1]
	if delta > 0 then
		for lnum = line + 1, max_line do
			if is_selectable_line(lnum) == true then
				vim.api.nvim_win_set_cursor(win, { lnum, 0 })
				return
			end
		end
		return
	end

	for lnum = line - 1, 1, -1 do
		if is_selectable_line(lnum) == true then
			vim.api.nvim_win_set_cursor(win, { lnum, 0 })
			return
		end
	end
end

function M.refresh()
	fetch_detail(true)
	local tab = resolve_tab_module(active_tab_key())
	if tab ~= nil and type(tab.refresh) == "function" then
		tab.refresh()
	end
end

---@param item BitbucketRepository|nil
function M.set_item(item)
	local previous_key = tostring((repo_state.item and repo_state.item.full_name) or "")
	local next_key = tostring((item and item.full_name) or "")

	repo_state.item = item
	if item == nil then
		clear_detail()
		select_tab(active_tab_key())
		return
	end

	fetch_detail(previous_key ~= next_key)
	select_tab(active_tab_key())
end

function M.next_tab()
	select_tab(next_tab_key(active_tab_key()))
end

function M.prev_tab()
	select_tab(prev_tab_key(active_tab_key()))
end

function M.deactivate()
	clear_detail()
	repo_state.reset()
	deactivate_tab(active_tab_key())
end

return M
