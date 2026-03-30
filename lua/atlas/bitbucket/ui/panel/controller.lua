local M = {}

local service = require("atlas.bitbucket.api.service")
local panel_state = require("atlas.bitbucket.ui.panel.state")
local renderer = require("atlas.bitbucket.ui.panel.renderer")
local spinner = require("atlas.ui.components.spinner")
local footer = require("atlas.ui.components.footer")

local panel_spinner = spinner.create({
	interval_ms = 120,
	on_tick = function()
		local detail_loading = panel_state.current_pr_detail == "loading"
		local activity_loading = panel_state.current_pr_activity == "loading"
		local comments_loading = panel_state.current_pr_comments == "loading"
		local commits_loading = panel_state.current_pr_commits == "loading"
		local diffstat_loading = panel_state.current_pr_diffstat == "loading"
		local diff_loading = panel_state.current_pr_diff == "loading"
		if
			not detail_loading
			and not activity_loading
			and not comments_loading
			and not commits_loading
			and not diffstat_loading
			and not diff_loading
		then
			panel_spinner:stop()
			return
		end
		renderer.render()
	end,
})

local active_handles = {
	reviewers = nil,
	activity = nil,
	comments = nil,
	commits = nil,
	diffstat = nil,
	diff = nil,
}

---@param key "reviewers"|"activity"|"comments"|"commits"|"diffstat"|"diff"
local function cancel_handle(key)
	local handle = active_handles[key]
	if handle ~= nil and handle.cancel then
		pcall(handle.cancel)
	end
	active_handles[key] = nil
end

local function cancel_all_handles()
	cancel_handle("reviewers")
	cancel_handle("activity")
	cancel_handle("comments")
	cancel_handle("commits")
	cancel_handle("diffstat")
	cancel_handle("diff")
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

local TAB_ORDER = {
	"overview",
	"activity",
	"comments",
	"commits",
	"files",
}

---@param item table
function M.on_select(item)
	cancel_all_handles()
	local pr = nil
	if type(item) == "table" then
		if type(item.pr) == "table" then
			pr = item.pr
		elseif item.kind == "pr" then
			pr = item
		end
	end

	panel_state.set_current(pr)
	if pr ~= nil then
		M.select_tab("overview")
	else
		panel_state.set_current_tab("overview")
		renderer.render()
		stop_spinner()
	end
end

---@param tab string
function M.select_tab(tab)
	panel_state.set_current_tab(tab)
	renderer.render()

	if tab == "overview" and panel_state.current_pr ~= nil then
		M.fetch_reviewers(tostring((panel_state.current_pr or {}).id or ""), 0)
	end

	if tab == "commits" and panel_state.current_pr ~= nil then
		M.fetch_commits(tostring((panel_state.current_pr or {}).id or ""), 0)
	end

	if tab == "activity" and panel_state.current_pr ~= nil then
		M.fetch_activity(tostring((panel_state.current_pr or {}).id or ""), 0)
	end

	if tab == "comments" and panel_state.current_pr ~= nil then
		M.fetch_comments(tostring((panel_state.current_pr or {}).id or ""), 0)
	end

	if tab == "files" and panel_state.current_pr ~= nil then
		M.fetch_diffstat(tostring((panel_state.current_pr or {}).id or ""), 0)
		M.fetch_diff(tostring((panel_state.current_pr or {}).id or ""), 0)
	end
end

function M.next_tab()
	local idx = 1
	for i, key in ipairs(TAB_ORDER) do
		if key == panel_state.current_tab then
			idx = i
			break
		end
	end

	local next_idx = idx + 1
	if next_idx > #TAB_ORDER then
		next_idx = 1
	end

	M.select_tab(TAB_ORDER[next_idx])
end

function M.prev_tab()
	local idx = 1
	for i, key in ipairs(TAB_ORDER) do
		if key == panel_state.current_tab then
			idx = i
			break
		end
	end

	local prev_idx = idx - 1
	if prev_idx < 1 then
		prev_idx = #TAB_ORDER
	end

	M.select_tab(TAB_ORDER[prev_idx])
end

---@param pr_key string
---@param request_id number
function M.fetch_activity(pr_key, request_id)
	local _ = request_id
	local pr = panel_state.current_pr
	if pr == nil then
		return
	end

	if tostring(pr.id or "") ~= tostring(pr_key or "") then
		return
	end

	local activity_url = ((pr.links or {}).activity or "")
	if activity_url == "" then
		return
	end

	local existing = panel_state.current_pr_activity
	if existing ~= "loading" and type(existing) == "table" and type(existing.entries) == "table" then
		return
	end

	panel_state.set_current_activity_loading()
	renderer.render()
	start_spinner()
	footer.notify("loading", "Loading activity...")

	cancel_handle("activity")
	local handle
	handle = service.fetch_pullrequest_activity(activity_url, { force_load = false }, function(activity, err)
		if active_handles.activity == handle then
			active_handles.activity = nil
		end
		if err ~= nil then
			if tostring((panel_state.current_pr or {}).id or "") == tostring(pr_key or "") then
				panel_state.set_current_activity(nil)
				renderer.render()
				footer.notify("error", string.format("Failed loading activity: %s", tostring(err)))
			end
			stop_spinner()
			return
		end

		if tostring((panel_state.current_pr or {}).id or "") ~= tostring(pr_key or "") then
			stop_spinner()
			return
		end

		panel_state.set_current_activity(activity)
		stop_spinner()
		renderer.render()
		footer.notify("success", "Activity loaded", 1200)
	end)
	active_handles.activity = handle
end

---@param pr_key string
---@param request_id number
function M.fetch_comments(pr_key, request_id)
	local _ = request_id
	local pr = panel_state.current_pr
	if pr == nil then
		return
	end

	if tostring(pr.id or "") ~= tostring(pr_key or "") then
		return
	end

	local comments_url = ((pr.links or {}).comments or "")
	if comments_url == "" then
		return
	end

	local existing = panel_state.current_pr_comments
	if existing ~= "loading" and type(existing) == "table" and type(existing.entries) == "table" then
		return
	end

	panel_state.set_current_comments_loading()
	renderer.render()
	start_spinner()
	footer.notify("loading", "Loading comments...")

	cancel_handle("comments")
	local handle
	handle = service.fetch_pullrequest_comments(comments_url, { force_load = false }, function(comments, err)
		if active_handles.comments == handle then
			active_handles.comments = nil
		end
		if err ~= nil then
			if tostring((panel_state.current_pr or {}).id or "") == tostring(pr_key or "") then
				panel_state.set_current_comments(nil)
				renderer.render()
				footer.notify("error", string.format("Failed loading comments: %s", tostring(err)))
			end
			stop_spinner()
			return
		end

		if tostring((panel_state.current_pr or {}).id or "") ~= tostring(pr_key or "") then
			stop_spinner()
			return
		end

		panel_state.set_current_comments(comments)
		stop_spinner()
		renderer.render()
		footer.notify("success", "Comments loaded", 1200)
	end)
	active_handles.comments = handle
end

---@param pr_key string
---@param request_id number
function M.fetch_commits(pr_key, request_id)
	local _ = request_id
	local pr = panel_state.current_pr
	if pr == nil then
		return
	end

	if tostring(pr.id or "") ~= tostring(pr_key or "") then
		return
	end

	local commits_url = ((pr.links or {}).commits or "")
	if commits_url == "" then
		return
	end

	local existing = panel_state.current_pr_commits
	if existing ~= "loading" and type(existing) == "table" and type(existing.entries) == "table" then
		return
	end

	panel_state.set_current_commits_loading()
	renderer.render()
	start_spinner()
	footer.notify("loading", "Loading commits...")

	cancel_handle("commits")
	local handle
	handle = service.fetch_pullrequest_commits(commits_url, { force_load = false }, function(commits, err)
		if active_handles.commits == handle then
			active_handles.commits = nil
		end
		if err ~= nil then
			if tostring((panel_state.current_pr or {}).id or "") == tostring(pr_key or "") then
				panel_state.set_current_commits(nil)
				renderer.render()
				footer.notify("error", string.format("Failed loading commits: %s", tostring(err)))
			end
			stop_spinner()
			return
		end

		if tostring((panel_state.current_pr or {}).id or "") ~= tostring(pr_key or "") then
			stop_spinner()
			return
		end

		panel_state.set_current_commits(commits)
		stop_spinner()
		renderer.render()
		footer.notify("success", "Commits loaded", 1200)
	end)
	active_handles.commits = handle
end

---@param pr_key string
---@param request_id number
function M.fetch_diffstat(pr_key, request_id)
	local _ = request_id
	local pr = panel_state.current_pr
	if pr == nil then
		return
	end

	if tostring(pr.id or "") ~= tostring(pr_key or "") then
		return
	end

	local diffstat_url = ((pr.links or {}).diffstat or "")
	if diffstat_url == "" then
		return
	end

	local existing = panel_state.current_pr_diffstat
	if existing ~= "loading" and type(existing) == "table" and type(existing.entries) == "table" then
		return
	end

	panel_state.set_current_diffstat_loading()
	renderer.render()
	start_spinner()
	footer.notify("loading", "Loading file changes...")

	cancel_handle("diffstat")
	local handle
	handle = service.fetch_pullrequest_diffstat(diffstat_url, { force_load = false }, function(diffstat, err)
		if active_handles.diffstat == handle then
			active_handles.diffstat = nil
		end
		if err ~= nil then
			if tostring((panel_state.current_pr or {}).id or "") == tostring(pr_key or "") then
				panel_state.set_current_diffstat(nil)
				renderer.render()
				footer.notify("error", string.format("Failed loading file changes: %s", tostring(err)))
			end
			stop_spinner()
			return
		end

		if tostring((panel_state.current_pr or {}).id or "") ~= tostring(pr_key or "") then
			stop_spinner()
			return
		end

		panel_state.set_current_diffstat(diffstat)
		stop_spinner()
		renderer.render()
		footer.notify("success", "File changes loaded", 1200)
	end)
	active_handles.diffstat = handle
end

---@param pr_key string
---@param request_id number
function M.fetch_diff(pr_key, request_id)
	local _ = request_id
	local pr = panel_state.current_pr
	if pr == nil then
		return
	end

	if tostring(pr.id or "") ~= tostring(pr_key or "") then
		return
	end

	local diff_url = ((pr.links or {}).diff or "")
	if diff_url == "" then
		return
	end

	local existing = panel_state.current_pr_diff
	if
		existing ~= "loading"
		and type(existing) == "table"
		and type(existing.text) == "string"
		and existing.text ~= ""
	then
		return
	end

	panel_state.set_current_diff_loading()
	renderer.render()
	start_spinner()
	footer.notify("loading", "Loading diff...")

	cancel_handle("diff")
	local handle
	handle = service.fetch_pullrequest_diff(diff_url, { force_load = false }, function(diff, err)
		if active_handles.diff == handle then
			active_handles.diff = nil
		end
		if err ~= nil then
			if tostring((panel_state.current_pr or {}).id or "") == tostring(pr_key or "") then
				panel_state.set_current_diff(nil)
				renderer.render()
				footer.notify("error", string.format("Failed loading diff: %s", tostring(err)))
			end
			stop_spinner()
			return
		end

		if tostring((panel_state.current_pr or {}).id or "") ~= tostring(pr_key or "") then
			stop_spinner()
			return
		end

		panel_state.set_current_diff(diff)
		stop_spinner()
		renderer.render()
		footer.notify("success", "Diff loaded", 1200)
	end)
	active_handles.diff = handle
end

---@param pr_key string
---@param request_id number
function M.fetch_reviewers(pr_key, request_id)
	local _ = request_id
	local pr = panel_state.current_pr
	if pr == nil then
		return
	end

	if tostring(pr.id or "") ~= tostring(pr_key or "") then
		return
	end

	local full_name = (pr.repo or {}).name or ""
	local workspace, repo = full_name:match("^([^/]+)/(.+)$")
	if workspace == nil or repo == nil then
		return
	end

	panel_state.set_current_detail_loading()
	renderer.render()
	start_spinner()
	footer.notify("loading", "Loading details...")

	cancel_handle("reviewers")
	local handle
	handle = service.fetch_pullrequest_detail(workspace, repo, pr.id, { force_load = false }, function(detail, err)
		if active_handles.reviewers == handle then
			active_handles.reviewers = nil
		end
		if err ~= nil then
			if tostring((panel_state.current_pr or {}).id or "") == tostring(pr_key or "") then
				panel_state.set_current_detail(nil)
				renderer.render()
				footer.notify("error", string.format("Failed loading details: %s", tostring(err)))
			end
			stop_spinner()
			return
		end

		if tostring((panel_state.current_pr or {}).id or "") ~= tostring(pr_key or "") then
			stop_spinner()
			return
		end

		panel_state.set_current_detail(detail)
		stop_spinner()
		renderer.render()
		footer.notify("success", "Details loaded", 1200)
	end)
	active_handles.reviewers = handle
end

function M.refresh()
	renderer.render()
end

function M.refresh_selected_pr()
	local pr = panel_state.current_pr
	if pr == nil then
		return
	end

	service.clear_pullrequest_memory_cache(pr)
	cancel_all_handles()

	panel_state.current_pr_detail = nil
	panel_state.current_pr_activity = nil
	panel_state.current_pr_comments = nil
	panel_state.current_pr_commits = nil
	panel_state.current_pr_diffstat = nil
	panel_state.current_pr_diff = nil

	renderer.render()

	local current_tab = panel_state.current_tab
	M.select_tab(current_tab)
end

return M
