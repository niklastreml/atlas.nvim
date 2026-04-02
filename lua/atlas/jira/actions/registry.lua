local M = {}

local transitions_api = require("atlas.jira.api.transitions")
local users_api = require("atlas.jira.api.users")
local issues_api = require("atlas.jira.api.issues")
local footer = require("atlas.ui.components.footer")

---@class JiraActionContext
---@field issue JiraIssue|nil
---@field source "panel"|"main"|nil

---@class JiraActionResult
---@field changed_issue boolean
---@field message string|nil

---@class JiraActionDef
---@field id string
---@field label string
---@field is_available fun(ctx: JiraActionContext): boolean
---@field run fun(ctx: JiraActionContext, done: fun(result: JiraActionResult|nil, err: string|nil))

---@param ctx JiraActionContext
---@return boolean
local function has_issue_key(ctx)
	return ctx.issue ~= nil and ctx.issue.key ~= ""
end

---@type JiraActionDef[]
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

			footer.notify("loading", string.format("Loading transitions for %s...", issue_key))
			transitions_api.get_transitions(issue_key, function(page, err)
				if err ~= nil or page == nil then
					footer.notify("error", err or "Failed to load transitions")
					done(nil, err or "Failed to load transitions")
					return
				end

				footer.notify("success", string.format("Loaded transitions for %s...", issue_key))

				local transitions = {}
				for _, transition in ipairs(page.transitions or {}) do
					local to_status = tostring((transition and transition.to_status_name) or "")
					if current_status == "" or to_status == "" or to_status ~= current_status then
						table.insert(transitions, transition)
					end
				end
				if #transitions == 0 then
					footer.notify("info", "No transitions available", 1200)
					done({ changed_issue = false, message = "No transitions available" }, nil)
					return
				end

				vim.ui.select(transitions, {
					prompt = string.format("Transition %s", issue_key),
					kind = "atlas_jira_transitions",
					format_item = function(item)
						return tostring((item and item.name) or "")
					end,
				}, function(selected)
					if selected == nil then
						done({ changed_issue = false, message = "Transition cancelled" }, nil)
						return
					end

					footer.notify("loading", string.format("Transitioning %s...", issue_key))
					transitions_api.transition_issue(issue_key, selected.id, function(ok, transition_err)
						if not ok then
							footer.notify("error", transition_err or "Transition failed")
							done(nil, transition_err or "Transition failed")
							return
						end

						footer.notify(
							"success",
							string.format("Transitioned %s to %s", issue_key, selected.name or "status"),
							1200
						)

						done({
							changed_issue = true,
							message = string.format("Transitioned to %s", selected.name or "status"),
						}, nil)
					end)
				end)
			end)
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
			local current_assignee = tostring(issue.assignee or "")

			footer.notify("loading", string.format("Loading assignable users for %s...", issue_key))
			users_api.get_assignable_users(issue_key, "", function(users, err)
				if err ~= nil or users == nil then
					footer.notify("error", err or "Failed loading assignable users")
					done(nil, err or "Failed loading assignable users")
					return
				end

				local current_assignee_key = vim.trim(current_assignee):lower()
				local options = {}
				if
					current_assignee_key ~= ""
					and current_assignee_key ~= "unassigned"
					and current_assignee_key ~= "none"
				then
					table.insert(options, { account_id = nil, display_name = "Unassign" })
				end

				for _, user in ipairs(users) do
					local user_name = tostring((user and user.display_name) or "")
					if vim.trim(user_name):lower() ~= current_assignee_key then
						table.insert(options, user)
					end
				end

				if #options == 0 then
					footer.notify("info", "No assignee options", 1200)
					done({ changed_issue = false, message = "No assignee options" }, nil)
					return
				end

				footer.notify("success", string.format("Loaded assignable users for %s", issue_key), 800)

				vim.ui.select(options, {
					prompt = string.format("Assign %s", issue_key),
					kind = "atlas_jira_assignees",
					format_item = function(item)
						return tostring((item and item.display_name) or "")
					end,
				}, function(selected)
					if selected == nil then
						done({ changed_issue = false, message = "Assign cancelled" }, nil)
						return
					end

					footer.notify("loading", string.format("Assigning %s...", issue_key))
					users_api.assign_issue(issue_key, selected.account_id, function(ok, assign_err)
						if not ok then
							footer.notify("error", assign_err or "Assign failed")
							done(nil, assign_err or "Assign failed")
							return
						end

						if selected.account_id == nil then
							footer.notify("success", string.format("Unassigned %s", issue_key), 1200)
							done({ changed_issue = true, message = "Unassigned" }, nil)
							return
						end

						footer.notify(
							"success",
							string.format("Assigned %s to %s", issue_key, selected.display_name),
							1200
						)
						done({
							changed_issue = true,
							message = string.format("Assigned to %s", selected.display_name),
						}, nil)
					end)
				end)
			end)
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
			local current_reporter = tostring(issue.reporter or "")

			footer.notify("loading", string.format("Loading users for reporter on %s...", issue_key))
			users_api.get_assignable_users(issue_key, "", function(users, err)
				if err ~= nil or users == nil then
					footer.notify("error", err or "Failed loading users")
					done(nil, err or "Failed loading users")
					return
				end

				local current_reporter_key = vim.trim(current_reporter):lower()
				local options = {}
				for _, user in ipairs(users) do
					local user_name = tostring((user and user.display_name) or "")
					if vim.trim(user_name):lower() ~= current_reporter_key then
						table.insert(options, user)
					end
				end

				if #options == 0 then
					footer.notify("info", "No reporter options", 1200)
					done({ changed_issue = false, message = "No reporter options" }, nil)
					return
				end

				footer.notify("success", string.format("Loaded users for %s", issue_key), 800)

				vim.ui.select(options, {
					prompt = string.format("Reporter for %s", issue_key),
					kind = "atlas_jira_reporters",
					format_item = function(item)
						return tostring((item and item.display_name) or "")
					end,
				}, function(selected)
					if selected == nil then
						done({ changed_issue = false, message = "Reporter change cancelled" }, nil)
						return
					end

					footer.notify("loading", string.format("Changing reporter for %s...", issue_key))
					users_api.change_reporter(issue_key, selected.account_id, function(ok, reporter_err)
						if not ok then
							footer.notify("error", reporter_err or "Reporter change failed")
							done(nil, reporter_err or "Reporter change failed")
							return
						end

						footer.notify(
							"success",
							string.format("Reporter for %s changed to %s", issue_key, selected.display_name),
							1200
						)
						done({
							changed_issue = true,
							message = string.format("Reporter changed to %s", selected.display_name),
						}, nil)
					end)
				end)
			end)
		end,
	},
	{
		id = "search_issues",
		label = "Search issues",
		is_available = function()
			return true
		end,
		run = function(_, done)
			vim.ui.input({
				prompt = "Search Jira issues (text or JQL): ",
			}, function(input)
				if input == nil then
					done({ changed_issue = false, message = "Search cancelled" }, nil)
					return
				end

				local query = vim.trim(tostring(input))
				if query == "" then
					done({ changed_issue = false, message = "Search query cannot be empty" }, nil)
					return
				end

				local lower = query:lower()
				local is_ticket_key = query:match("^[A-Z]+%-%d+$") ~= nil
				local looks_like_jql = query:find("[=<>~]") ~= nil
					or lower:match("^%s*order%s+by%s+") ~= nil
					or lower:find(" and ", 1, true) ~= nil
					or lower:find(" or ", 1, true) ~= nil

				local jql = nil
				if is_ticket_key then
					jql = string.format('key = "%s"', query)
				elseif looks_like_jql then
					jql = query
				else
					local escaped_query = query:gsub("\\", "\\\\"):gsub('"', '\\"')
					jql = string.format('text ~ "%s" ORDER BY updated DESC', escaped_query)
				end

				local search_view = {
					name = "Search (JQL)",
					jql = jql,
				}

				require("atlas.jira.ui.controller").switch_view(search_view, function()
					require("atlas.ui.navigation").focus_first_item()
				end)
				done({ changed_issue = false, message = "Search view opened" }, nil)
			end)
		end,
	},
	{
		id = "edit_title",
		label = "Edit title",
		is_available = has_issue_key,
		run = function(ctx, done)
			local issue = ctx.issue
			if not has_issue_key(ctx) or issue == nil then
				done(nil, "No issue selected")
				return
			end

			local issue_key = issue.key
			local current_title = tostring(issue.summary or "")

			vim.ui.input({
				prompt = string.format("Title for %s: ", issue_key),
				default = current_title,
			}, function(input)
				if input == nil then
					done({ changed_issue = false, message = "Edit title cancelled" }, nil)
					return
				end

				local new_title = vim.trim(tostring(input))
				if new_title == "" then
					done({ changed_issue = false, message = "Title cannot be empty" }, nil)
					return
				end

				if new_title == current_title then
					done({ changed_issue = false, message = "Title unchanged" }, nil)
					return
				end

				footer.notify("loading", string.format("Updating title for %s...", issue_key))
				issues_api.update_issue(issue_key, { summary = new_title }, function(ok, err)
					if not ok then
						footer.notify("error", err or "Failed to update title")
						done(nil, err or "Failed to update title")
						return
					end

					footer.notify("success", string.format("Title updated for %s", issue_key), 1200)
					done({ changed_issue = true, message = "Title updated" }, nil)
				end)
			end)
		end,
	},
}

---@param ctx JiraActionContext
---@return JiraActionDef[]
function M.available(ctx)
	local out = {}
	for _, action in ipairs(ACTIONS) do
		if action.is_available(ctx) then
			table.insert(out, action)
		end
	end
	return out
end

---@param id string
---@return JiraActionDef|nil
function M.find(id)
	for _, action in ipairs(ACTIONS) do
		if action.id == id then
			return action
		end
	end
	return nil
end

return M
