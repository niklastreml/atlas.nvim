local M = {}

local config = require("atlas.config")
local footer = require("atlas.ui.components.footer")
local helper = require("atlas.bitbucket.ui.helper")
local service = require("atlas.bitbucket.api.service")
local spinner = require("atlas.ui.popups.spinner")
local state = require("atlas.bitbucket.state")
local ui_state = require("atlas.ui.state")
local window = require("atlas.ui.window")

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

	state.is_loading = true
	state.error = nil

	if window.is_open() then
		require("atlas.ui.renderer").render("bitbucket")
	end

	local request_scope = string.format("bitbucket:%s", tostring(ui_state.buf_id or "default"))
	service.fetch_pullrequests((target_view and target_view.repos) or {}, {
		force_load = opts.force_load == true,
		request_scope = request_scope,
	}, function(groups, err)
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
			state.repos = {}
		else
			state.error = nil
			state.repos = groups or {}
		end

		footer.set_items("bitbucket", helper.build_footer_items(state.repos))

		spinner.stop()

		if window.is_open() then
			require("atlas.ui.renderer").render("bitbucket")
		end

		on_done()
	end)
end

---@param on_done fun()|nil
function M.refresh_current_view(on_done)
	load_active_view({ force_load = true }, on_done)
end

---@param view BitbucketViewConfig|nil
---@param on_done fun()|nil
function M.switch_view(view, on_done)
	state.active_view = view
	load_active_view({ force_load = false }, on_done)
end

return M
