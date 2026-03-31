local M = {}

local config = require("atlas.config")
local footer = require("atlas.ui.components.footer")
local spinner = require("atlas.ui.popups.spinner")
local state = require("atlas.jira.state")
local layout = require("atlas.ui.layout")
local users = require("atlas.jira.api.users")
local issues_api = require("atlas.jira.api.issues")
local service = require("atlas.jira.api.service")
local logger = require("atlas.core.logger")

local active_user_handle = nil
local active_issues_handle = nil

local function cancel_active_requests()
	if active_user_handle ~= nil and active_user_handle.cancel then
		pcall(active_user_handle.cancel)
	end
	active_user_handle = nil

	if active_issues_handle ~= nil and active_issues_handle.cancel then
		pcall(active_issues_handle.cancel)
	end
	active_issues_handle = nil
end

---@param view JiraViewConfig|nil
---@return string
local function view_id(view)
	if view == nil then
		return "default"
	end
	return view.key or view.name or "default"
end

---@param a JiraViewConfig|nil
---@param b JiraViewConfig|nil
---@return boolean
local function same_view(a, b)
	if a == nil and b == nil then
		return true
	end
	if a == nil or b == nil then
		return false
	end
	return view_id(a) == view_id(b)
end

---@return integer
local function next_request_token()
	state.request_seq = (state.request_seq or 0) + 1
	return state.request_seq
end

---@param on_done fun(err: string|nil)
local function get_current_user(on_done)
	if state.current_user ~= nil then
		on_done(nil)
		return
	end

	active_user_handle = users.get_myself(function(user, err)
		active_user_handle = nil
		if err ~= nil then
			on_done(tostring(err))
			return
		end
		state.current_user = user
		on_done(nil)
	end)
end

---@param view JiraViewConfig
---@return string
local function build_jql(view)
	local jql = view.jql
	if jql and jql ~= "" then
		if jql:find("%%s") then
			return string.format(jql, view.project)
		end
		return jql
	end
	return string.format("project = '%s' ORDER BY updated DESC", view.project)
end

---@param opts { force_load: boolean }|nil
---@param on_done fun()|nil
local function load_active_view(opts, on_done)
	on_done = on_done or function() end
	opts = opts or { force_load = false }

	local views = (config.options.jira and config.options.jira.views) or {}
	if state.active_view == nil and views[1] then
		state.active_view = views[1]
	end

	local target_view = state.active_view
	if target_view == nil then
		state.is_loading = false
		state.error = "No Jira views configured"
		if layout.is_open() then
			require("atlas.ui.main.renderer").render("jira")
		end
		on_done()
		return
	end

	local target_view_id = view_id(target_view)
	local token = next_request_token()
	state.latest_request_tokens[target_view_id] = token
	cancel_active_requests()

	state.is_loading = true
	state.error = nil
	footer.notify("loading", "Loading issues...")
	spinner.start("Loading issues...")

	if layout.is_open() then
		require("atlas.ui.main.renderer").render("jira")
	end

	get_current_user(function(user_err)
		if not same_view(state.active_view, target_view) then
			return
		end
		if state.latest_request_tokens[target_view_id] ~= token then
			return
		end

		if user_err then
			state.is_loading = false
			state.current_view = state.active_view
			state.error = tostring(user_err)
			state.issues = nil
			state.issue_tree = nil
			footer.notify("error", string.format("Failed to fetch current user: %s", tostring(user_err)))
			spinner.stop()
			if layout.is_open() then
				require("atlas.ui.main.renderer").render("jira")
			end
			on_done()
			return
		end

		local jql = build_jql(target_view)
		logger.loginfo("Jira loading view", { view = target_view_id, jql = jql })

		active_issues_handle = issues_api.search_issues(jql, function(issues, err)
			active_issues_handle = nil

			if not same_view(state.active_view, target_view) then
				return
			end
			if state.latest_request_tokens[target_view_id] ~= token then
				return
			end

			state.is_loading = false
			state.current_view = state.active_view

			if err then
				state.error = tostring(err)
				state.issues = nil
				state.issue_tree = nil
				footer.notify("error", string.format("Failed to fetch issues: %s", tostring(err)))
			else
				state.error = nil
				state.issues = issues or {}
				state.issue_tree = require("atlas.jira.api.normalizer").build_issue_tree(state.issues)
				footer.notify("success", string.format("Loaded %d issues", #(issues or {})), 1200)
			end

			spinner.stop()

			if layout.is_open() then
				require("atlas.ui.main.renderer").render("jira")
			end

			on_done()
		end, { force_load = opts.force_load == true })
	end)
end

---@param on_done fun()|nil
function M.refresh_current_view(on_done)
	service.clear_memory_cache()
	load_active_view({ force_load = true }, on_done)
end

---@param view JiraViewConfig|nil
---@param on_done fun()|nil
function M.switch_view(view, on_done)
	state.active_view = view
	load_active_view({ force_load = false }, on_done)
end

return M
