local M = {}

local config = require("atlas.config")
local footer = require("atlas.ui.components.footer")
local spinner = require("atlas.ui.popups.spinner")
local state = require("atlas.bitbucket.state")
local layout = require("atlas.ui.layout")
local service = require("atlas.bitbucket.api.service")
local users = require("atlas.bitbucket.api.users")
local pullrequests = require("atlas.bitbucket.api.pullrequests")
local helper = require("atlas.bitbucket.ui.helper")
local navigation = require("atlas.ui.navigation")
local renderer = require("atlas.bitbucket.ui.renderer")
local info_popup = require("atlas.ui.popups.info")

local active_user_handle = nil
local active_pullrequests_handle = nil

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

	active_user_handle = users.fetch_current_user(function(user, err)
		active_user_handle = nil
		if err ~= nil then
			on_done(tostring(err))
			return
		end
		state.current_user = user
		on_done(nil)
	end)
end

---@param groups BitbucketPRViewGroup[]|nil
---@param view BitbucketViewConfig|nil
---@return BitbucketPRViewGroup[]
local function apply_filter(groups, view)
	local source = groups or {}
	local view_filter = (view and view.filter) or nil
	if view_filter == nil then
		return source
	end

	local ctx = {
		user = state.current_user or {},
	}

	local filtered_groups = {}
	for _, group in ipairs(source) do
		local prs = {}
		for _, pr in ipairs(group.prs or {}) do
			local ok, keep = pcall(view_filter, pr, ctx)
			if ok and keep == true then
				table.insert(prs, pr)
			end
		end

		if #prs > 0 then
			table.insert(filtered_groups, {
				workspace = group.workspace,
				repo = group.repo,
				full_name = group.full_name,
				prs = prs,
			})
		end
	end

	return filtered_groups
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
	local target_view_id = helper.view_id(target_view)
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

	local function is_stale_request()
		if not helper.same_view(state.active_view, target_view) then
			return true
		end

		if state.latest_request_tokens[target_view_id] ~= token then
			return true
		end

		return false
	end

	local function finalize_fetch(prs, err)
		if is_stale_request() then
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

		local grouped_prs = helper.group_prs_by_repo(prs)
		local filtered_groups = apply_filter(grouped_prs, target_view)
		local has_groups = #filtered_groups > 0

		if first_err ~= nil then
			if has_groups then
				state.error = nil
				state.repos = filtered_groups
				footer.notify("warn", string.format("Some repositories failed: %s", tostring(first_err)))
			else
				state.error = tostring(first_err)
				state.repos = {}
				footer.notify("error", string.format("Failed to fetch pull requests: %s", tostring(first_err)))
			end
		else
			state.error = nil
			state.repos = filtered_groups
			footer.notify("success", "Pull requests loaded", 1200)
		end

		footer.set_items(helper.build_footer_items(state.repos, state.current_user))
		spinner.stop()

		if layout.is_open() then
			require("atlas.ui.main.renderer").render("bitbucket")
		end

		on_done()
	end

	local function fetch_pull_requests()
		if is_stale_request() then
			return
		end

		active_pullrequests_handle = pullrequests.fetch_pullrequests((target_view and target_view.repos) or {}, {
			force_load = opts.force_load == true,
		}, function(prs, err)
			active_pullrequests_handle = nil
			finalize_fetch(prs, err)
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

			footer.set_items(helper.build_footer_items(state.repos or {}, state.current_user))
			if layout.is_open() then
				require("atlas.ui.main.renderer").render("bitbucket")
			end
		end)
	end

	fetch_pull_requests()
end

---@param on_done fun()|nil
function M.refresh_current_view(on_done)
	service.clear_memory_cache()
	load_active_view({ force_load = true }, on_done)
end

---@param pr BitbucketPR|nil
---@param on_done fun()|nil
function M.refresh_pr(pr, on_done)
	on_done = on_done or function() end

	if pr == nil or pr.id == nil then
		footer.notify("warn", "No PR selected")
		on_done()
		return
	end

	local pr_id = pr.id
	local workspace = tostring(pr.workspace or "")
	local repo = tostring(pr.repo or "")

	if workspace == "" or repo == "" then
		footer.notify("warn", "PR missing workspace/repo info")
		on_done()
		return
	end

	footer.notify("loading", string.format("Reloading PR #%s...", tostring(pr_id)))

	pullrequests.fetch_pullrequest(workspace, repo, pr_id, function(fetched_pr, err)
		if err ~= nil or fetched_pr == nil then
			footer.notify("error", tostring(err or "Failed to reload PR"))
			on_done()
			return
		end

		-- Replace the PR in state.repos
		local repos = state.repos or {}
		local replaced = false

		for _, group in ipairs(repos) do
			if group.workspace == workspace and group.repo == repo then
				for i, existing_pr in ipairs(group.prs or {}) do
					if existing_pr.id == pr_id then
						group.prs[i] = fetched_pr
						replaced = true
						break
					end
				end
			end
			if replaced then
				break
			end
		end

		state.repos = repos
		if layout.is_open() then
			require("atlas.ui.main.renderer").render("bitbucket")
		end

		-- Update panel if open and showing the same PR
		local panel = require("atlas.ui.panel")
		if panel.is_open() then
			local ui_panel_state = require("atlas.ui.panel.state")
			local current_panel_pr = require("atlas.bitbucket.panel.state").current_pr
			local current_panel_id = type(current_panel_pr) == "table" and current_panel_pr.id or nil

			if ui_panel_state.active_provider == "bitbucket" and current_panel_id == pr_id then
				panel.on_select({
					provider = "bitbucket",
					panel_type = "pr",
					item = fetched_pr,
				})
			end
		end

		footer.notify("success", string.format("Reloaded PR #%s", tostring(pr_id)), 1200)
		on_done()
	end)
end

---Refresh the currently selected PR in the main view.
---@param on_done fun()|nil
function M.refresh_current_pr(on_done)
	local navigation = require("atlas.ui.navigation")
	local node = navigation.current_item()

	if type(node) ~= "table" or node.kind ~= "pr" then
		footer.notify("warn", "No PR selected")
		if on_done then
			on_done()
		end
		return
	end

	M.refresh_pr(node.data, on_done)
end

---@param view BitbucketViewConfig|nil
---@param on_done fun()|nil
function M.switch_view(view, on_done)
	state.active_view = view
	load_active_view({ force_load = false }, on_done)
end

---@param source_buf integer|nil
function M.show_pr_details(source_buf)
	local node = navigation.current_item()
	if type(node) ~= "table" or node.kind ~= "pr" then
		footer.notify("warn", "No PR selected")
		return
	end

	local pr = type(node.pr) == "table" and node.pr or node
	if type(pr) ~= "table" or pr.id == nil then
		footer.notify("warn", "PR payload missing on line")
		return
	end

	local lines, highlights = renderer.pr_popup_content(pr)
	info_popup.show({
		lines = lines,
		highlights = highlights,
		source_buf = source_buf,
	})
end

return M
