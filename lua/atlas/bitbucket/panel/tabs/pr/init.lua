local M = {}
local pr_state = require("atlas.bitbucket.panel.tabs.pr.state")
local pullrequests = require("atlas.bitbucket.api.pullrequests")
local footer = require("atlas.ui.components.footer")

local TABS = {
	{ key = "overview", label = "Overview", mod = "atlas.bitbucket.panel.tabs.pr.overview" },
	{ key = "activity", label = "Activity", mod = "atlas.bitbucket.panel.tabs.pr.activity" },
	{ key = "comments", label = "Comments", mod = "atlas.bitbucket.panel.tabs.pr.comments" },
	{ key = "commits", label = "Commits", mod = "atlas.bitbucket.panel.tabs.pr.commits" },
	{ key = "files", label = "Files", mod = "atlas.bitbucket.panel.tabs.pr.files" },
}

local statuses_handle = nil
local statuses_key = nil

local function cancel_statuses_request()
	if statuses_handle ~= nil and statuses_handle.cancel then
		pcall(statuses_handle.cancel)
	end
	statuses_handle = nil
end

local function clear_statuses()
	cancel_statuses_request()
	statuses_key = nil
	pr_state.statuses = nil
end

---@param force boolean
local function fetch_statuses(force)
	local pr = pr_state.item
	if pr == nil then
		clear_statuses()
		return
	end

	local statuses_url = tostring((pr.links or {}).statuses or "")
	if statuses_url == "" then
		pr_state.statuses = nil
		return
	end

	if not force and statuses_key == statuses_url and pr_state.statuses ~= nil and pr_state.statuses ~= "loading" then
		return
	end
	if not force and statuses_key == statuses_url and pr_state.statuses == "loading" then
		return
	end

	cancel_statuses_request()
	statuses_key = statuses_url
	pr_state.statuses = "loading"

	statuses_handle = pullrequests.fetch_statuses(statuses_url, {
		force_load = force == true,
	}, function(statuses, err)
		statuses_handle = nil

		local current = pr_state.item
		local current_key = current and tostring((current.links or {}).statuses or "") or ""

		if current_key ~= statuses_url then
			return
		end

		if err ~= nil then
			pr_state.statuses = nil
			footer.notify("error", "Failed to load PR statuses: " .. tostring(err))
		else
			pr_state.statuses = statuses
		end
	end)
end

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
	return pr_state.tab or "overview"
end

---@param tab_key string
local function activate_tab(tab_key)
	local tab = resolve_tab_module(tab_key)
	if tab ~= nil and type(tab.activate) == "function" then
		tab.activate(pr_state.item)
	end
end

---@param tab_key string
local function deactivate_tab(tab_key)
	local tab = resolve_tab_module(tab_key)
	if tab ~= nil and type(tab.deactivate) == "function" then
		tab.deactivate()
	end
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
	local step = delta > 0 and 1 or -1
	if is_selectable_line(line) ~= true then
		local target = math.max(1, math.min(max_line, line + step))
		vim.api.nvim_win_set_cursor(win, { target, 0 })
		return
	end

	if step > 0 then
		for lnum = line + 1, max_line do
			if is_selectable_line(lnum) == true then
				vim.api.nvim_win_set_cursor(win, { lnum, 0 })
				return
			end
		end
	else
		for lnum = line - 1, 1, -1 do
			if is_selectable_line(lnum) == true then
				vim.api.nvim_win_set_cursor(win, { lnum, 0 })
				return
			end
		end
	end

	local target = math.max(1, math.min(max_line, line + step))
	vim.api.nvim_win_set_cursor(win, { target, 0 })
end

---@param opts? { force_load?: boolean }
function M.refresh(opts)
	opts = opts or {}
	fetch_statuses(opts.force_load == true)

	local tab = resolve_tab_module(active_tab_key())
	if tab ~= nil and type(tab.refresh) == "function" then
		tab.refresh(opts)
	end
end

---@param tab_key string
local function select_tab(tab_key)
	deactivate_tab(pr_state.tab)
	pr_state.tab = tab_key
	activate_tab(tab_key)
	M.move(0)
end

---@param item BitbucketPR|nil
function M.set_item(item)
	pr_state.item = item
	if item == nil then
		clear_statuses()
		select_tab(active_tab_key())
		return
	end

	fetch_statuses(false)
	select_tab(active_tab_key())
end

function M.next_tab()
	select_tab(next_tab_key(active_tab_key()))
end

function M.prev_tab()
	select_tab(prev_tab_key(active_tab_key()))
end

function M.deactivate()
	clear_statuses()
	deactivate_tab(active_tab_key())
end

function M.reset()
	clear_statuses()
	for _, tab in ipairs(TABS) do
		local mod = resolve_tab_module(tab.key)
		if mod ~= nil and type(mod.reset) == "function" then
			mod.reset()
		end
	end
end

return M
