local M = {}

local icons = require("atlas.ui.shared.icons")
local footer = require("atlas.ui.components.footer")
local async_picker = require("atlas.ui.components.async_picker")
local issues_api = require("atlas.issues.providers.jira.api.issues")
local transitions_api = require("atlas.issues.providers.jira.api.transitions")
local users_api = require("atlas.issues.providers.jira.api.users")
local issues_state = require("atlas.issues.state")
local service = require("atlas.issues.providers.jira.api.service")

---@param ctx table
---@return boolean
local function has_issue_key(ctx)
	local issue = type(ctx) == "table" and ctx.issue or nil
	if type(issue) ~= "table" then
		return false
	end
	local key = tostring(issue.key or "")
	return key ~= ""
end

---@type table[]
local ACTIONS = {
	{
		id = "transition",
		label = "Transition",
		is_available = has_issue_key,
		run = function(ctx, done)
			local issue = ctx.issue
			if not has_issue_key(ctx) or issue == nil then
				done(nil, "No issue selected")
				return
			end

			local issue_key = issue.key
			local current_status = tostring(issue.status or "")
			local all_items = nil

			local status_category_icons = {
				new = icons.fallback(),
				indeterminate = icons.general("info"),
				done = icons.general("success"),
			}

			async_picker.open({
				title = string.format("Transition %s", issue_key),
				prompt = "Filter transitions",
				debounce_ms = 0,
				identifier = "jira_transitions:" .. issue_key,
				format_item = function(item)
					local transition = item.value
					local category = type(transition) == "table" and transition.to_status_category or nil
					local icon = (category and status_category_icons[category]) or icons.fallback()
					return string.format("%s %s", icon, item.label)
				end,
				fetch = function(fetch_ctx, fetch_done)
					if all_items then
						local query = vim.trim(fetch_ctx.query):lower()
						if query == "" then
							fetch_done(all_items, nil)
							return
						end
						local filtered = {}
						for _, item in ipairs(all_items) do
							if item.label:lower():find(query, 1, true) then
								table.insert(filtered, item)
							end
						end
						fetch_done(filtered, nil)
						return
					end

					transitions_api.get_transitions(issue_key, function(transitions, err)
						if err ~= nil or transitions == nil then
							fetch_done(nil, err or "Failed to load transitions")
							return
						end

						all_items = {}
						for _, transition in ipairs(transitions) do
							local to_status = tostring((transition and transition.to_status_name) or "")
							if current_status == "" or to_status == "" or to_status ~= current_status then
								table.insert(all_items, {
									id = tostring(transition.id or ""),
									label = tostring(transition.name or ""),
									value = transition,
								})
							end
						end
						fetch_done(all_items, nil)
					end)
				end,
				on_select = function(item)
					local selected = item.value
					footer.notify("loading", string.format("Transitioning %s...", issue_key))
					transitions_api.transition_issue(issue_key, selected.id, function(ok, err)
						if not ok then
							footer.notify("error", err or "Transition failed")
							done(nil, err or "Transition failed")
							return
						end

						footer.notify("success", string.format("Transitioned %s to %s", issue_key, selected.name or ""), 1200)
						done({ changed_issue_key = issue_key, message = string.format("Transitioned to %s", selected.name or "") }, nil)
					end)
				end,
				on_cancel = function()
					done({ changed_issue_key = nil, message = "Transition cancelled" }, nil)
				end,
			})
		end,
	},
	{
		id = "assign",
		label = "Change assignee",
		is_available = has_issue_key,
		run = function(ctx, done)
			local issue = ctx.issue
			if not has_issue_key(ctx) or issue == nil then
				done(nil, "No issue selected")
				return
			end

			local issue_key = issue.key
			local issue_project_key = issue.project and issue.project.key or nil
			local current_assignee_key = vim.trim(tostring(issue.assignee and issue.assignee.display_name or "")):lower()

			local function to_picker_items(users)
				local items = {}
				local current_user = issues_state.current_user
				local current_user_account_id = current_user and current_user.account_id or nil
				local current_user_item = nil
				local seen_current_user = false

				if current_assignee_key ~= "" and current_assignee_key ~= "unassigned" then
					table.insert(items, {
						id = "__unassign__",
						label = "Unassign",
						value = { account_id = nil, display_name = "Unassign" },
					})
				end

				for _, user in ipairs(users or {}) do
					local user_name = vim.trim(tostring(user.display_name or "")):lower()
					if user_name ~= current_assignee_key then
						local item = { id = user.account_id or "", label = user.display_name or "", value = user }
						if current_user_account_id and user.account_id == current_user_account_id then
							seen_current_user = true
							current_user_item = item
						else
							table.insert(items, item)
						end
					end
				end

				if current_user_account_id then
					if not seen_current_user then
						current_user_item = {
							id = current_user_account_id,
							label = current_user.display_name or "",
							value = current_user,
						}
					end
					if current_user_item then
						table.insert(items, 1, current_user_item)
					end
				end

				return items
			end

			async_picker.open({
				title = string.format("Assign %s", issue_key),
				prompt = "Search users",
				initial_items = to_picker_items({}),
				debounce_ms = 250,
				cache_ttl_ms = 60000,
				identifier = "jira_users:" .. (issue_project_key or ""),
				fetch_on_open = false,
				format_item = function(item)
					if item.id == "__unassign__" then
						return item.label
					end
					return string.format("%s %s", icons.general("user"), item.label)
				end,
				fetch = function(fetch_ctx, fetch_done)
					users_api.get_assignable_users(
						{ issue_key = issue_key, project = issue_project_key },
						fetch_ctx.query,
						function(users, err)
							if err then
								fetch_done(nil, err)
								return
							end
							fetch_done(to_picker_items(users), nil)
						end
					)
				end,
				on_select = function(item)
					local selected = item.value
					footer.notify("loading", string.format("Assigning %s...", issue_key))
					users_api.assign_issue(issue_key, selected.account_id, function(ok, err)
						if not ok then
							footer.notify("error", err or "Assign failed")
							done(nil, err or "Assign failed")
							return
						end

						if selected.account_id == nil then
							footer.notify("success", string.format("Unassigned %s", issue_key), 1200)
							done({ changed_issue_key = issue_key, message = "Unassigned" }, nil)
							return
						end

						footer.notify("success", string.format("Assigned %s to %s", issue_key, selected.display_name), 1200)
						done({ changed_issue_key = issue_key, message = string.format("Assigned to %s", selected.display_name) }, nil)
					end)
				end,
				on_cancel = function()
					done({ changed_issue_key = nil, message = "Assign cancelled" }, nil)
				end,
			})
		end,
	},
	{
		id = "reporter",
		label = "Change reporter",
		is_available = has_issue_key,
		run = function(ctx, done)
			local issue = ctx.issue
			if not has_issue_key(ctx) or issue == nil then
				done(nil, "No issue selected")
				return
			end

			local issue_key = issue.key
			local current_reporter_key = vim.trim(tostring(type(issue.reporter) == "table" and issue.reporter.display_name or "")):lower()

			local function to_picker_items(users)
				local items = {}
				for _, user in ipairs(users or {}) do
					local user_name = vim.trim(tostring(user.display_name or "")):lower()
					if user_name ~= current_reporter_key then
						table.insert(items, { id = user.account_id or "", label = user.display_name or "", value = user })
					end
				end
				return items
			end

			async_picker.open({
				title = string.format("Reporter for %s", issue_key),
				prompt = "Search users",
				initial_items = {},
				debounce_ms = 250,
				cache_ttl_ms = 60000,
				fetch_on_open = false,
				format_item = function(item)
					return string.format("%s %s", icons.general("user"), item.label)
				end,
				fetch = function(fetch_ctx, fetch_done)
					users_api.get_assignable_users(
						{ issue_key = issue_key, project = nil },
						fetch_ctx.query,
						function(users, err)
							if err then
								fetch_done(nil, err)
								return
							end
							fetch_done(to_picker_items(users), nil)
						end
					)
				end,
				on_select = function(item)
					local selected = item.value
					footer.notify("loading", string.format("Changing reporter for %s...", issue_key))
					users_api.change_reporter(issue_key, selected.account_id, function(ok, err)
						if not ok then
							footer.notify("error", err or "Reporter change failed")
							done(nil, err or "Reporter change failed")
							return
						end

						footer.notify("success", string.format("Reporter for %s changed to %s", issue_key, selected.display_name), 1200)
						done({ changed_issue_key = issue_key, message = string.format("Reporter changed to %s", selected.display_name) }, nil)
					end)
				end,
				on_cancel = function()
					done({ changed_issue_key = nil, message = "Reporter change cancelled" }, nil)
				end,
			})
		end,
	},
	{
		id = "search_query_issue",
		label = "Search Issue",
		is_available = function()
			return true, nil
		end,
		run = function(_, done)
			async_picker.open({
				title = "Search Query",
				prompt = "Search tickets",
				debounce_ms = 200,
				identifier = "jira_issue_picker_search",
				cache_ttl_ms = 30000,
				fetch_on_open = true,
				format_item = function(item)
					return string.format("%s %s", icons.issues_provider("jira", "provider"), tostring(item.label or ""))
				end,
				fetch = function(fetch_ctx, fetch_done)
					local query = vim.trim(fetch_ctx.query)
					issues_api.search_issue(query, function(items, err)
						if fetch_ctx.signal.cancelled then
							return
						end

						if err ~= nil or items == nil then
							fetch_done(nil, err or "Failed to search tickets")
							return
						end

						local picker_items = {}
						for _, issue in ipairs(items) do
							table.insert(picker_items, {
								id = tostring(issue.id or issue.key),
								label = string.format("%s - %s", issue.key, issue.summary),
								secondary = issue.key,
								value = issue,
							})
						end

						fetch_done(picker_items, nil)
					end)
				end,
				on_select = function(item)
					local issue = item.value
					local issue_key = tostring((issue or {}).key or "")
					if issue_key == "" then
						done(nil, "Selected issue is missing key")
						return
					end

					local search_view = {
						name = string.format("Search (%s)", issue_key),
						jql = string.format('key = "%s"', issue_key),
					}

					require("atlas.issues.ui.main.controller").switch_view(search_view)
					done({ changed_issue_key = issue_key, message = string.format("Opened %s", issue_key) }, nil)
				end,
				on_cancel = function()
					done({ changed_issue_key = nil, message = "Search cancelled" }, nil)
				end,
			})
		end,
	},
	{
		id = "browse_issue",
		label = "Open Issue In Browser",
		is_available = has_issue_key,
		run = function(ctx, done)
			local issue = ctx.issue
			if not has_issue_key(ctx) or issue == nil then
				done(nil, "No issue selected")
				return
			end

			local base_url = tostring(service.jira_config().base_url or ""):gsub("/$", "")
			local issue_key = tostring(issue.key or "")
			if base_url == "" or issue_key == "" then
				done(nil, "No URL found for issue")
				return
			end

			vim.ui.open(string.format("%s/browse/%s", base_url, issue_key))
			done({ changed_issue_key = nil, message = string.format("Opened %s in browser", issue_key) }, nil)
		end,
	},
	{
		id = "copy_issue_key",
		label = "Copy Issue Key",
		is_available = has_issue_key,
		run = function(ctx, done)
			local issue = ctx.issue
			if not has_issue_key(ctx) or issue == nil then
				done(nil, "No issue selected")
				return
			end

			local issue_key = tostring(issue.key or "")
			if issue_key == "" then
				done(nil, "Nothing to copy")
				return
			end

			vim.fn.setreg("+", issue_key)
			vim.fn.setreg('"', issue_key)
			done({ changed_issue_key = nil, message = "Copied issue key" }, nil)
		end,
	},
	{
		id = "copy_issue_url",
		label = "Copy Issue URL",
		is_available = has_issue_key,
		run = function(ctx, done)
			local issue = ctx.issue
			if not has_issue_key(ctx) or issue == nil then
				done(nil, "No issue selected")
				return
			end

			local base_url = tostring(service.jira_config().base_url or ""):gsub("/$", "")
			local issue_key = tostring(issue.key or "")
			local url = (base_url ~= "" and issue_key ~= "") and string.format("%s/browse/%s", base_url, issue_key)
				or ""
			if url == "" then
				done(nil, "No URL found for issue")
				return
			end

			vim.fn.setreg("+", url)
			vim.fn.setreg('"', url)
			done({ changed_issue_key = nil, message = "Copied issue URL" }, nil)
		end,
	},
}

---@param ctx table
---@return table[]
function M.available(ctx)
	local out = {}
	for _, action in ipairs(ACTIONS) do
		local ok = action.is_available(ctx)
		if ok then
			table.insert(out, action)
		end
	end
	return out
end

---@param id string
---@return table|nil
function M.find(id)
	for _, action in ipairs(ACTIONS) do
		if action.id == id then
			return action
		end
	end
	return nil
end

return M
