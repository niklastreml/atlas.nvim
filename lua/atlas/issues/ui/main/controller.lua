local M = {}

local footer = require("atlas.ui.components.footer")
local spinner = require("atlas.ui.popups.spinner")
local status_spinner = require("atlas.ui.components.spinner")
local state = require("atlas.issues.state")
local layout = require("atlas.ui.layout")
local navigation = require("atlas.ui.navigation")
local info_popup = require("atlas.ui.popups.info")
local helper = require("atlas.issues.ui.main.helper")

local active_issues_handle = nil
local active_issue_reload_handles = {}

local function render_if_active()
	if not layout.is_open() then
		return
	end

	local ui_main_state = require("atlas.ui.state")
	local provider = state.provider
	if provider == nil or ui_main_state.current_view ~= provider.id then
		return
	end

	require("atlas.issues.ui.main").render()
end

local refresh_status_spinner = status_spinner.create({
	interval_ms = 120,
	on_tick = function(frame)
		state.reload_spinner_frame = frame
		render_if_active()
	end,
})

local function cancel_issue_reload_handles()
	for _, handle in ipairs(active_issue_reload_handles) do
		if handle ~= nil and handle.cancel then
			pcall(handle.cancel)
		end
	end
	active_issue_reload_handles = {}
end

local function reset_reload_state()
	refresh_status_spinner:stop()
	state.reloading_issue_keys = {}
	state.reload_spinner_frame = "⠋"
end

local function has_reloading_issues()
	for _, count in pairs(state.reloading_issue_keys or {}) do
		if (tonumber(count) or 0) > 0 then
			return true
		end
	end
	return false
end

---@param issue_key string
local function begin_issue_reload(issue_key)
	state.reloading_issue_keys = state.reloading_issue_keys or {}
	state.reloading_issue_keys[issue_key] = (tonumber(state.reloading_issue_keys[issue_key]) or 0) + 1

	if not refresh_status_spinner:is_running() then
		refresh_status_spinner:start()
	end

	state.reload_spinner_frame = refresh_status_spinner:current_frame()
	render_if_active()
end

---@param issue_key string
local function end_issue_reload(issue_key)
	state.reloading_issue_keys = state.reloading_issue_keys or {}
	local next_count = (tonumber(state.reloading_issue_keys[issue_key]) or 0) - 1
	if next_count > 0 then
		state.reloading_issue_keys[issue_key] = next_count
	else
		state.reloading_issue_keys[issue_key] = nil
	end

	if not has_reloading_issues() then
		refresh_status_spinner:stop()
		state.reload_spinner_frame = "⠋"
	end

	render_if_active()
end

local function cancel_active_requests()
	if active_issues_handle ~= nil and active_issues_handle.cancel then
		pcall(active_issues_handle.cancel)
	end
	active_issues_handle = nil

	cancel_issue_reload_handles()
	reset_reload_state()
end

---@param view IssuesViewConfig|nil
---@return string
local function view_id(view)
	if view == nil then
		return "default"
	end
	return view.key or view.name or "default"
end

---@param a IssuesViewConfig|nil
---@param b IssuesViewConfig|nil
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

	local provider = state.provider
	if provider == nil then
		on_done("no provider")
		return
	end

	provider.fetch_user(function(user, err)
		if err ~= nil then
			on_done(tostring(err))
			return
		end
		state.current_user = user
		on_done(nil)
	end)
end

---@param opts { force_load: boolean }|nil
---@param on_done fun()|nil
local function load_active_view(opts, on_done)
	on_done = on_done or function() end
	opts = opts or { force_load = false }

	local provider = state.provider
	if provider == nil then
		on_done()
		return
	end

	local target_view = state.active_view
	if target_view == nil then
		state.is_loading = false
		state.error = "No issues views configured"
		footer.notify("error", state.error)
		render_if_active()
		on_done()
		return
	end

	local target_view_id = view_id(target_view)
	local token = next_request_token()
	state.latest_request_tokens[target_view_id] = token
	cancel_active_requests()

	state.is_loading = true
	state.error = nil
	state.issues = nil
	state.issue_tree = nil
	state.line_map = {}
	footer.notify("loading", "Loading issues...")
	spinner.start("Loading issues...")
	if not refresh_status_spinner:is_running() then
		refresh_status_spinner:start()
	end
	state.reload_spinner_frame = refresh_status_spinner:current_frame()

	render_if_active()

	local function is_stale_request()
		if not same_view(state.active_view, target_view) then
			return true
		end
		if state.latest_request_tokens[target_view_id] ~= token then
			return true
		end
		return false
	end

	local function finish_loading()
		state.is_loading = false
		if not has_reloading_issues() then
			refresh_status_spinner:stop()
		end
		spinner.stop()
	end

	local function finalize_fetch_failure(err, issues)
		if is_stale_request() then
			return
		end

		finish_loading()
		state.current_view = state.active_view

		if #issues > 0 then
			state.error = nil
			state.issues = issues
			state.issue_tree = helper.build_issue_tree(issues)
			footer.notify("warn", string.format("Stopped at %d issues: %s", #issues, tostring(err)))
		else
			state.error = tostring(err)
			state.issues = nil
			state.issue_tree = nil
			footer.notify("error", string.format("Failed to fetch issues: %s", tostring(err)))
		end

		render_if_active()
		on_done()
	end

	local function finalize_fetch_success(issues)
		if is_stale_request() then
			return
		end

		state.current_view = state.active_view
		state.error = nil
		state.issues = issues
		state.issue_tree = helper.build_issue_tree(issues)
		finish_loading()

		footer.notify("success", string.format("Loaded %d issues", #issues), 1200)
		render_if_active()
		on_done()
	end

	local function fetch_page(next_page_token, issues)
		if is_stale_request() then
			return
		end

		issues = issues or {}
		active_issues_handle = provider.fetch_issues(target_view, {
			force_load = opts.force_load == true,
			next_page_token = next_page_token,
		}, function(page_issues, next_token, is_last, err)
			active_issues_handle = nil

			if is_stale_request() then
				return
			end

			if err ~= nil then
				finalize_fetch_failure(err, issues)
				return
			end

			for _, issue in ipairs(page_issues or {}) do
				table.insert(issues, issue)
			end

			state.current_view = state.active_view
			state.error = nil
			state.issues = issues
			state.issue_tree = helper.build_issue_tree(issues)
			render_if_active()

			if is_last ~= true and next_token ~= nil and next_token ~= "" then
				fetch_page(next_token, issues)
				return
			end

			finalize_fetch_success(issues)
		end)
	end

	if state.current_user == nil then
		get_current_user(function(user_err)
			if is_stale_request() then
				return
			end
			if user_err then
				footer.notify("warn", string.format("Failed to fetch current user: %s", tostring(user_err)))
				return
			end
			render_if_active()
		end)
	end

	fetch_page(nil, {})
end

---@param on_done fun()|nil
function M.refresh_current_view(on_done)
	local service = require("atlas.issues.providers.jira.api.service")
	service.clear_memory_cache()

	load_active_view({ force_load = true }, function()
		navigation.focus_first_item()
		if on_done ~= nil then
			on_done()
		end
	end)
end

---@param view IssuesViewConfig|nil
function M.switch_view(view)
	state.active_view = view
	load_active_view({ force_load = false }, function()
		navigation.focus_first_item()
	end)
end

---@param source_buf integer|nil
function M.show_issue_details(source_buf)
	local node = navigation.current_item()
	if type(node) ~= "table" or node.kind ~= "issue" then
		footer.notify("warn", "No issue selected")
		return
	end

	local issue = type(node._issue) == "table" and node._issue or nil
	if issue == nil then
		footer.notify("warn", "Issue payload missing on line")
		return
	end

	local renderer = require("atlas.issues.ui.main.renderer")
	local lines, highlights = renderer.issue_popup_content(issue)
	info_popup.show({
		lines = lines,
		highlights = highlights,
		source_buf = source_buf,
	})
end

function M.open_actions()
	local node = navigation.current_item()
	if type(node) ~= "table" or node.kind ~= "issue" then
		footer.notify("warn", "No issue selected")
		return
	end

	local issue = type(node._issue) == "table" and node._issue or nil
	if issue == nil then
		footer.notify("warn", "Issue payload missing on line")
		return
	end

	local actions = require("atlas.issues.actions")
	actions.open_actions(issue, "main")
end

---@param issue_key string|nil
---@param on_done fun()|nil
function M.refresh_issue(issue_key, on_done)
	on_done = on_done or function() end

	issue_key = type(issue_key) == "string" and issue_key or ""
	if issue_key == "" then
		footer.notify("warn", "Issue key missing")
		on_done()
		return
	end

	local provider = state.provider
	if provider == nil then
		on_done()
		return
	end

	footer.notify("loading", string.format("Reloading %s...", issue_key))
	begin_issue_reload(issue_key)
 local reload_handle = nil
	reload_handle = provider.fetch_issue(issue_key, { force_load = true }, function(fetched_issue, err)
		for i = #active_issue_reload_handles, 1, -1 do
			if active_issue_reload_handles[i] == reload_handle then
				table.remove(active_issue_reload_handles, i)
				break
			end
		end

		if err ~= nil or fetched_issue == nil then
			end_issue_reload(issue_key)
			footer.notify("error", tostring(err or "Failed to reload issue"))
			on_done()
			return
		end

		local issues = state.issues or {}
		local replaced = false
		for i, existing in ipairs(issues) do
			if type(existing) == "table" and existing.key == issue_key then
				issues[i] = fetched_issue
				replaced = true
				break
			end
		end

		if not replaced then
			table.insert(issues, fetched_issue)
		end

		state.issues = issues
		state.issue_tree = helper.build_issue_tree(issues)
		end_issue_reload(issue_key)

		render_if_active()
		footer.notify("success", string.format("Reloaded %s", issue_key), 1200)
		on_done()
	end)
	table.insert(active_issue_reload_handles, reload_handle)
end

---@param issue_key string|nil
function M.toggle_issue_collapsed(issue_key)
	if state.toggle_issue_collapsed(issue_key) ~= true then
		return
	end

	render_if_active()
end

function M.toggle_current_issue_collapsed()
	if state.toggle_current_issue_collapsed() ~= true then
		return
	end
	render_if_active()
end

---@param on_done fun()|nil
function M.refresh_current_issue(on_done)
	local node = navigation.current_item()
	if type(node) ~= "table" or node.kind ~= "issue" then
		footer.notify("warn", "No issue selected")
		if on_done then
			on_done()
		end
		return
	end

	local issue = type(node._issue) == "table" and node._issue or nil
	local issue_key = type(issue) == "table" and tostring(issue.key or "") or ""
	M.refresh_issue(issue_key, on_done)
end

return M
