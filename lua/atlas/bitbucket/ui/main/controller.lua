local M = {}

local config = require("atlas.config")
local footer = require("atlas.ui.components.footer")
local helper = require("atlas.bitbucket.ui.main.helper")
local service = require("atlas.bitbucket.api.service")
local spinner = require("atlas.ui.popups.spinner")
local state = require("atlas.bitbucket.state")
local layout = require("atlas.ui.layout")

local active_pullrequests_handle = nil
local active_user_handle = nil

local function cancel_active_requests()
	if active_user_handle ~= nil and active_user_handle.cancel then
		pcall(active_user_handle.cancel)
	end
	active_user_handle = nil

	if active_pullrequests_handle ~= nil and active_pullrequests_handle.cancel then
		pcall(active_pullrequests_handle.cancel)
	end
	active_pullrequests_handle = nil
end

---@param view BitbucketViewConfig|nil
---@return string
local function view_id(view)
	if view == nil then
		return "default"
	end

	return view.key or view.name or "default"
end

---@param a BitbucketViewConfig|nil
---@param b BitbucketViewConfig|nil
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

	active_user_handle = service.fetch_current_user(function(user, err)
		if active_user_handle ~= nil then
			active_user_handle = nil
		end
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

	local views = (config.options.bitbucket and config.options.bitbucket.views) or {}
	if state.active_view == nil and views[1] then
		state.active_view = views[1]
	end

	local target_view = state.active_view
	local target_view_id = view_id(target_view)
	local token = next_request_token()
	state.latest_request_tokens[target_view_id] = token
	cancel_active_requests()

	state.is_loading = true
	state.error = nil
	footer.notify("loading", "Loading pull requests...")
	spinner.start("Loading pull requests...")

	if layout.is_open() then
		require("atlas.ui.main.renderer").render("bitbucket")
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
			state.repos = {}
			footer.notify("error", string.format("Failed to fetch current user: %s", tostring(user_err)))
			spinner.stop()
			if layout.is_open() then
				require("atlas.ui.main.renderer").render("bitbucket")
			end
			on_done()
			return
		end

		active_pullrequests_handle = service.fetch_pullrequests((target_view and target_view.repos) or {}, {
			force_load = opts.force_load == true,
		}, function(groups, err)
			if active_pullrequests_handle ~= nil then
				active_pullrequests_handle = nil
			end

			if not same_view(state.active_view, target_view) then
				return
			end

			if state.latest_request_tokens[target_view_id] ~= token then
				return
			end

			state.is_loading = false
			state.current_view = state.active_view
			local first_err = nil
			if type(err) == "table" then
				first_err = err[1]
			elseif err ~= nil then
				first_err = err
			end

			if first_err ~= nil then
				state.error = tostring(first_err)
				state.repos = {}
				footer.notify("error", string.format("Failed to fetch pull requests: %s", tostring(first_err)))
			else
				state.error = nil
				state.repos = groups or {}
				footer.notify("success", "Pull requests loaded", 1200)
			end

			footer.set_items(helper.build_footer_items(state.repos, state.current_user))

			spinner.stop()

			if layout.is_open() then
				require("atlas.ui.main.renderer").render("bitbucket")
			end

			on_done()
		end)
	end)
end

---@param on_done fun()|nil
function M.refresh_current_view(on_done)
	service.clear_memory_cache()
	load_active_view({ force_load = true }, on_done)
end

---@param view BitbucketViewConfig|nil
---@param on_done fun()|nil
function M.switch_view(view, on_done)
	state.active_view = view
	load_active_view({ force_load = false }, on_done)
end

return M
