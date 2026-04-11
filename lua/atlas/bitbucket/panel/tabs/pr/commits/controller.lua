local M = {}
local state = require("atlas.bitbucket.panel.tabs.pr.commits.state")
local pullrequests = require("atlas.bitbucket.api.pullrequests")
local footer = require("atlas.ui.components.footer")
local helper = require("atlas.bitbucket.panel.tabs.pr.helper")

local active_handle = nil
local status_handles = {}
local status_batch = 0
local MAX_STATUS_COMMITS = 5

local function cancel_active_handle()
	if active_handle ~= nil and active_handle.cancel then
		pcall(active_handle.cancel)
	end
	active_handle = nil
end

local function cancel_status_handles()
	for key, handle in pairs(status_handles) do
		if handle ~= nil and handle.cancel then
			pcall(handle.cancel)
		end
		status_handles[key] = nil
	end
end

---@return boolean
local function has_status_requests()
	return next(status_handles) ~= nil
end

---@param pr BitbucketPR|nil
---@param commits BitbucketPRCommits|nil
---@param force_load boolean
local function fetch_commit_builds(pr, commits, force_load)
	cancel_status_handles()
	status_batch = status_batch + 1
	local batch = status_batch
	local pr_id = pr and pr.id or nil

	state.commit_status_by_hash = {}
	state.commit_build_url_by_hash = {}
	if pr == nil or commits == nil or type(commits.entries) ~= "table" then
		return
	end

	local count = math.min(MAX_STATUS_COMMITS, #commits.entries)
	for i = 1, count do
		local commit = commits.entries[i]
		local hash = tostring(commit.hash or "")
		local statuses_url = tostring(commit.statuses_url or "")
		if hash ~= "" and statuses_url ~= "" then
			state.commit_status_by_hash[hash] = "loading"
			status_handles[hash] = pullrequests.fetch_commit_statuses(statuses_url, {
				force_load = force_load == true,
			}, function(statuses, err)
				if batch ~= status_batch then
					return
				end
				status_handles[hash] = nil

				local current = state.pr
				if current == nil or current.id ~= pr_id then
					return
				end

				if err ~= nil then
					state.commit_status_by_hash[hash] = "unknown"
					state.commit_build_url_by_hash[hash] = nil
				else
					state.commit_status_by_hash[hash] = helper.statuses.aggregate(statuses)
					state.commit_build_url_by_hash[hash] = helper.statuses.first_url(statuses)
				end
			end)
		end
	end
end

---@param pr BitbucketPR|nil
function M.show(pr)
	local prev_id = state.pr and state.pr.id or nil
	local next_id = pr and pr.id or nil
	local same_pr = prev_id == next_id

	if not same_pr then
		cancel_active_handle()
		cancel_status_handles()
		state.commit_status_by_hash = {}
		state.commit_build_url_by_hash = {}
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
			fetch_commit_builds(pr, commits, false)
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
	cancel_status_handles()
	state.commit_status_by_hash = {}
	state.commit_build_url_by_hash = {}
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
			fetch_commit_builds(state.pr, commits, opts.force_load == true)
			footer.notify("success", "Commits refreshed", 1200)
		end

	end)
end

function M.reset()
	cancel_active_handle()
	cancel_status_handles()
	state.reset()
end

function M.deactivate() end

---@param lnum integer
---@return boolean
local function is_commit_line(lnum)
	local item = state.line_map[lnum]
	if item == nil or item.commit == nil then
		return false
	end

	return item.kind == "header"
		or item.kind == "thread_header"
		or item.kind == "content"
		or item.kind == "thread_content"
end

---@return boolean
function M.open_current_line()
	local layout = require("atlas.ui.layout")
	local win = layout.win_id("detail")
	if win == nil or not vim.api.nvim_win_is_valid(win) then
		return false
	end

	local lnum = vim.api.nvim_win_get_cursor(win)[1]
	local entry = state.line_map[lnum]
	if type(entry) ~= "table" then
		return false
	end

	local url = tostring(entry.build_url or "")
	if url == "" then
		return false
	end

	vim.ui.open(url)
	return true
end

---@return boolean
function M.is_loading()
	return state.commits == "loading" or has_status_requests()
end

---@param lnum integer
---@return boolean
function M.is_selectable_line(lnum)
	return is_commit_line(lnum)
end

return M
