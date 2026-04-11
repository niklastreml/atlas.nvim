local M = {}
local pr_state = require("atlas.bitbucket.panel.tabs.pr.state")

local TABS = {
	{ key = "overview", label = "Overview", mod = "atlas.bitbucket.panel.tabs.pr.overview" },
	{ key = "activity", label = "Activity", mod = "atlas.bitbucket.panel.tabs.pr.activity" },
	{ key = "comments", label = "Comments", mod = "atlas.bitbucket.panel.tabs.pr.comments" },
	{ key = "commits", label = "Commits", mod = "atlas.bitbucket.panel.tabs.pr.commits" },
	{ key = "files", label = "Files", mod = "atlas.bitbucket.panel.tabs.pr.files" },
}

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
	if tab ~= nil and type(tab.move_cursor) == "function" then
		tab.move_cursor(delta)
	end
end

function M.refresh()
	local tab = resolve_tab_module(active_tab_key())
	if tab ~= nil and type(tab.refresh) == "function" then
		tab.refresh()
	end
end

---@param tab_key string
local function select_tab(tab_key)
	deactivate_tab(pr_state.tab)
	pr_state.tab = tab_key
	activate_tab(tab_key)
end

---@param item BitbucketPR|nil
function M.set_item(item)
	pr_state.item = item
	select_tab(active_tab_key())
end

function M.next_tab()
	select_tab(next_tab_key(active_tab_key()))
end

function M.prev_tab()
	select_tab(prev_tab_key(active_tab_key()))
end

function M.deactivate()
	deactivate_tab(active_tab_key())
end

return M
