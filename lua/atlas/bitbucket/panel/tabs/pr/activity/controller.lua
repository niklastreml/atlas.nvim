local M = {}
local state = require("atlas.bitbucket.panel.tabs.pr.activity.state")
local pullrequests = require("atlas.bitbucket.api.pullrequests")
local footer = require("atlas.ui.components.footer")

local active_handle = nil

---@param lnum integer
---@return boolean
local function is_activity_line(lnum)
	local item = state.line_map[lnum]
	if item == nil then
		return false
	end
	return item.kind == "header"
		or item.kind == "content"
		or item.kind == "thread_header"
		or item.kind == "thread_content"
end

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

	if same_pr and state.activity == "loading" then
		state.pr = pr
		state.line_map = {}
		return
	end

	state.pr = pr
	state.line_map = {}

	if pr == nil then
		state.activity = nil
		return
	end

	if same_pr and state.activity ~= nil and state.activity ~= "loading" then
		return
	end

	local activity_url = pr.links.activity
	if activity_url == "" then
		state.activity = nil
		footer.notify("error", "Missing activity URL")
		return
	end

	state.activity = "loading"
	footer.notify("loading", "Loading activity...")

	active_handle = pullrequests.fetch_activity(activity_url, {}, function(activity, err)
		active_handle = nil

		if state.pr == nil or state.pr.id ~= next_id then
			return
		end

		if err ~= nil then
			state.activity = nil
			footer.notify("error", "Failed to load activity: " .. tostring(err))
		else
			state.activity = activity
			footer.notify("success", "Activity loaded", 1200)
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

	local activity_url = pr.links.activity
	if activity_url == "" then
		return
	end

	cancel_active_handle()
	state.activity = "loading"

	active_handle = pullrequests.fetch_activity(
		activity_url,
		{ force_load = opts.force_load == true },
		function(activity, err)
			active_handle = nil

			if state.pr == nil then
				return
			end

			if err ~= nil then
				state.activity = nil
				footer.notify("error", "Failed to refresh activity")
			else
				state.activity = activity
				footer.notify("success", "Activity refreshed", 1200)
			end
		end
	)
end

function M.reset()
	cancel_active_handle()
	state.reset()
end

function M.deactivate() end

---@return boolean
function M.is_loading()
	return state.activity == "loading"
end

---@param lnum integer
---@return boolean
function M.is_selectable_line(lnum)
	return is_activity_line(lnum)
end

return M
