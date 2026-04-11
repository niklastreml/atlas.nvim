local M = {}
local state = require("atlas.bitbucket.panel.tabs.pr.overview.state")
local pullrequests = require("atlas.bitbucket.api.pullrequests")
local footer = require("atlas.ui.components.footer")
local layout = require("atlas.ui.layout")

local active_handle = nil
local diffstat_handle = nil

local function cancel_active_handle()
	if active_handle ~= nil and active_handle.cancel then
		pcall(active_handle.cancel)
	end
	active_handle = nil

	if diffstat_handle ~= nil and diffstat_handle.cancel then
		pcall(diffstat_handle.cancel)
	end
	diffstat_handle = nil
end

---@param pr BitbucketPR|nil
function M.show(pr)
	local prev_id = state.pr and state.pr.id or nil
	local next_id = pr and pr.id or nil
	local same_pr = prev_id == next_id

	if not same_pr then
		cancel_active_handle()
	end

	local detail_loading = state.detail == "loading"
	local diffstat_loading = state.diffstat == "loading"

	if same_pr and (detail_loading or diffstat_loading) then
		state.pr = pr
		state.line_map = {}
		return
	end

	state.pr = pr
	state.line_map = {}

	if pr == nil then
		state.detail = nil
		state.diffstat = nil
		return
	end

	local workspace = pr.workspace
	local repo_slug = pr.repo
	local pr_id = tostring(pr.id)

	if workspace == "" or repo_slug == "" or pr_id == "" then
		state.detail = nil
		state.diffstat = nil
		footer.notify("error", "Missing PR info for detail fetch")
		return
	end

	local needs_detail = not (same_pr and state.detail ~= nil and state.detail ~= "loading")
	local needs_diffstat = not (same_pr and state.diffstat ~= nil and state.diffstat ~= "loading")

	if not needs_detail and not needs_diffstat then
		return
	end

	footer.notify("loading", string.format("Loading PR #%s...", pr_id))

	if needs_detail then
		state.detail = "loading"

		active_handle = pullrequests.fetch_pullrequest(workspace, repo_slug, pr_id, {}, function(detail, err)
			active_handle = nil

			if state.pr == nil or tostring(state.pr.id) ~= pr_id then
				return
			end

			if err ~= nil then
				state.detail = nil
				footer.notify("error", string.format("Failed to load PR #%s: %s", pr_id, tostring(err)))
			else
				state.detail = detail
			end

			if state.diffstat ~= "loading" then
				footer.notify("success", string.format("PR #%s loaded", pr_id), 1200)
			end

		end)
	end

	if needs_diffstat then
		local diffstat_url = pr.links.diffstat
		if diffstat_url ~= "" then
			state.diffstat = "loading"

			diffstat_handle = pullrequests.fetch_diffstat(diffstat_url, {}, function(diffstat, err)
				diffstat_handle = nil

				if state.pr == nil or tostring(state.pr.id) ~= pr_id then
					return
				end

				if err ~= nil then
					state.diffstat = nil
				else
					state.diffstat = diffstat
				end

				if state.detail ~= "loading" then
					footer.notify("success", string.format("PR #%s loaded", pr_id), 1200)
				end

			end)
		else
			state.diffstat = nil
		end
	end
end

---@param opts? { force_load?: boolean }
function M.refresh(opts)
	opts = opts or {}
	local force_load = opts.force_load == true
	local pr = state.pr
	if pr == nil then
		return
	end

	local workspace = pr.workspace
	local repo_slug = pr.repo
	local pr_id = tostring(pr.id)

	if workspace == "" or repo_slug == "" or pr_id == "" then
		return
	end

	cancel_active_handle()
	state.detail = "loading"
	state.diffstat = "loading"

	active_handle =
		pullrequests.fetch_pullrequest(workspace, repo_slug, pr_id, { force_load = force_load }, function(detail, err)
		active_handle = nil

		if state.pr == nil or tostring(state.pr.id) ~= pr_id then
			return
		end

		if err ~= nil then
			state.detail = nil
			footer.notify("error", string.format("Failed to refresh PR #%s", pr_id))
		else
			state.detail = detail
		end

		if state.diffstat ~= "loading" then
			footer.notify("success", string.format("PR #%s refreshed", pr_id), 1200)
		end

	end)

	local diffstat_url = pr.links.diffstat
	if diffstat_url ~= "" then
		diffstat_handle = pullrequests.fetch_diffstat(diffstat_url, { force_load = force_load }, function(diffstat, err)
			diffstat_handle = nil

			if state.pr == nil or tostring(state.pr.id) ~= pr_id then
				return
			end

			if err ~= nil then
				state.diffstat = nil
			else
				state.diffstat = diffstat
			end

			if state.detail ~= "loading" then
				footer.notify("success", string.format("PR #%s refreshed", pr_id), 1200)
			end

		end)
	else
		state.diffstat = nil
	end
end

function M.reset()
	cancel_active_handle()
	state.reset()
end

function M.deactivate()
end

---@return boolean
function M.open_current_line()
	local win = layout.win_id("detail")
	if win == nil or not vim.api.nvim_win_is_valid(win) then
		return false
	end

	local lnum = vim.api.nvim_win_get_cursor(win)[1]
	local entry = state.line_map[lnum]
	if type(entry) ~= "table" or entry.kind ~= "build" then
		return false
	end

	local url = tostring(entry.url or "")
	if url == "" then
		return false
	end

	vim.ui.open(url)
	return true
end

---@return boolean
function M.is_loading()
	return state.detail == "loading" or state.diffstat == "loading"
end

---@param _lnum integer
---@return boolean
function M.is_selectable_line(_lnum)
	return true
end

return M
