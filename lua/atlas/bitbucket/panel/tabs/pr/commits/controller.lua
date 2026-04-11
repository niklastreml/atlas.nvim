local M = {}
local state = require("atlas.bitbucket.panel.tabs.pr.commits.state")
local pullrequests = require("atlas.bitbucket.api.pullrequests")
local footer = require("atlas.ui.components.footer")

local active_handle = nil

local function cancel_active_handle()
	if active_handle ~= nil and active_handle.cancel then
		pcall(active_handle.cancel)
	end
	active_handle = nil
end

---@param pr BitbucketPR|nil
function M.show(pr)
	local prev_id = state.pr and state.pr.id or nil
	local next_id = pr and pr.id or nil
	local same_pr = prev_id == next_id

	if not same_pr then
		cancel_active_handle()
	end

	if same_pr and state.commits == "loading" then
		state.pr = pr
		state.line_map = {}
		return
	end

	state.pr = pr
	state.line_map = {}

	if pr == nil then
		state.commits = nil
		return
	end

	if same_pr and state.commits ~= nil and state.commits ~= "loading" then
		return
	end

	local commits_url = pr.links.commits
	if commits_url == "" then
		state.commits = nil
		footer.notify("error", "Missing commits URL")
		return
	end

	state.commits = "loading"
	footer.notify("loading", "Loading commits...")

	active_handle = pullrequests.fetch_commits(commits_url, {}, function(commits, err)
		active_handle = nil

		if state.pr == nil or state.pr.id ~= next_id then
			return
		end

		if err ~= nil then
			state.commits = nil
			footer.notify("error", "Failed to load commits: " .. tostring(err))
		else
			state.commits = commits
			footer.notify("success", "Commits loaded", 1200)
		end

	end)
end

---@param opts? { force_load?: boolean }
function M.refresh(opts)
	opts = opts or {}
	local pr = state.pr
	if pr == nil then
		return
	end

	local commits_url = pr.links.commits
	if commits_url == "" then
		return
	end

	cancel_active_handle()
	state.commits = "loading"

	active_handle = pullrequests.fetch_commits(commits_url, { force_load = opts.force_load == true }, function(commits, err)
		active_handle = nil

		if state.pr == nil then
			return
		end

		if err ~= nil then
			state.commits = nil
			footer.notify("error", "Failed to refresh commits")
		else
			state.commits = commits
			footer.notify("success", "Commits refreshed", 1200)
		end

	end)
end

function M.reset()
	cancel_active_handle()
	state.reset()
end

function M.deactivate() end

---@return integer|nil
local function detail_win()
	local layout = require("atlas.ui.layout")
	local win = layout.win_id("detail")
	if win == nil or not vim.api.nvim_win_is_valid(win) then
		return nil
	end
	return win
end

---@param lnum integer
---@return boolean
local function is_commit_line(lnum)
	local item = state.line_map[lnum]
	if item == nil or item.commit == nil then
		return false
	end

	return item.kind == "header" or item.kind == "thread_header"
end

---@param win integer
---@param delta integer
---@return boolean
local function jump_next_commit(win, delta)
	local line = vim.api.nvim_win_get_cursor(win)[1]
	local buf = vim.api.nvim_win_get_buf(win)
	local max_line = vim.api.nvim_buf_line_count(buf)
	local step = delta > 0 and 1 or -1

	for lnum = line + step, (step > 0 and max_line or 1), step do
		if is_commit_line(lnum) then
			vim.api.nvim_win_set_cursor(win, { lnum, 0 })
			return true
		end
	end

	return false
end

---@return boolean
function M.is_loading()
	return state.commits == "loading"
end

---@param lnum integer
---@return boolean
function M.is_selectable_line(lnum)
	return is_commit_line(lnum)
end

return M
