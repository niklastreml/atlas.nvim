local M = {}

local transitions_api = require("atlas.jira.api.transitions")
local users_api = require("atlas.jira.api.users")
local issues_api = require("atlas.jira.api.issues")
local jira_state = require("atlas.jira.state")
local config = require("atlas.config")
local issue_editor = require("atlas.jira.ui.issue")
local adf = require("atlas.jira.converted.adf")
local footer = require("atlas.ui.components.footer")

---@class JiraActionContext
---@field issue JiraIssue|nil
---@field source "panel"|"main"|nil
---@field description string|nil

---@class JiraActionResult
---@field changed_issue_key string|nil
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

---@return string[]
local function get_unique_projects()
	local jira = config.options and config.options.jira
	local views = jira and jira.views
	if not views or #views == 0 then
		return {}
	end

	local seen = {}
	local projects = {}
	for _, view in ipairs(views) do
		local p = view.project
		if p and p ~= "" and not seen[p] then
			seen[p] = true
			table.insert(projects, p)
		end
	end
	return projects
end

---@param opts IssueFields
---@param on_submit fun(fields: IssueFields, submit_done: fun(ok: boolean, err: string|nil))
local function open_issue_ui(opts, on_submit)
	issue_editor.open(function(fields, submit_done)
		on_submit(fields, submit_done or function() end)
	end, opts)
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
					done({ changed_issue_key = nil, message = "No transitions available" }, nil)
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
						done({ changed_issue_key = nil, message = "Transition cancelled" }, nil)
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
							changed_issue_key = issue_key,
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
			local current_assignee = type(issue.assignee) == "table" and issue.assignee.display_name or ""

			footer.notify("loading", string.format("Loading assignable users for %s...", issue_key))
			users_api.get_assignable_users(
				{ issue_key = issue_key, project = issue.project.key },
				"",
				function(users, err)
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
						done({ changed_issue_key = nil, message = "No assignee options" }, nil)
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
							done({ changed_issue_key = nil, message = "Assign cancelled" }, nil)
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
								done({ changed_issue_key = issue_key, message = "Unassigned" }, nil)
								return
							end

							footer.notify(
								"success",
								string.format("Assigned %s to %s", issue_key, selected.display_name),
								1200
							)
							done({
								changed_issue_key = issue_key,
								message = string.format("Assigned to %s", selected.display_name),
							}, nil)
						end)
					end)
				end
			)
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
			users_api.get_assignable_users({ issue_key = issue_key, project = nil }, "", function(users, err)
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
					footer.notify("info", "No reporter found", 1200)
					done({ changed_issue_key = nil, message = "No reporter options" }, nil)
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
						done({ changed_issue_key = nil, message = "Reporter change cancelled" }, nil)
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
							changed_issue_key = issue_key,
							message = string.format("Reporter changed to %s", selected.display_name),
						}, nil)
					end)
				end)
			end)
		end,
	},
	{
		id = "edit_issue",
		label = "Edit Issue",
		is_available = has_issue_key,
		run = function(ctx, done)
			local issue = ctx.issue
			if not has_issue_key(ctx) or issue == nil then
				done(nil, "No issue selected")
				return
			end

			local issue_key = issue.key

			local function open_issue_editor(initial_description)
				open_issue_ui({
					summary = tostring(issue.summary or ""),
					description = initial_description,
					assignee = issue.assignee,
					reporter = jira_state.current_user,
					project = issue.project and issue.project.key or "",
					issue_key = issue.key,
					issue_type = issue.type,
				}, function(fields, submit_done)
					local payload = {
						summary = fields.summary,
						description = fields.description or vim.NIL,
					}

					if fields.issue_type and fields.issue_type.id and fields.issue_type.id ~= "" then
						payload.issuetype = { id = fields.issue_type.id }
					end

					if fields.assignee and fields.assignee.account_id then
						payload.assignee = { id = fields.assignee.account_id }
					else
						payload.assignee = vim.NIL
					end

					footer.notify("loading", string.format("Updating issue %s...", issue_key))
					issues_api.update_issue(issue_key, payload, function(ok, err)
						if not ok then
							submit_done(false, err or "Failed to update issue")
							done(nil, err or "Failed to update issue")
							return
						end

						footer.notify("success", string.format("Updated %s", issue_key), 1200)
						submit_done(true, nil)
						done({ changed_issue_key = issue_key, message = "Issue updated" }, nil)
					end)
				end)
			end

			--- When editing from main we dont have the description yet, so we need to load it before.
			if ctx.description ~= nil then
				open_issue_editor(ctx.description)
				return
			end

			footer.notify("loading", string.format("Loading description for %s...", issue_key))
			issues_api.get_issue_description(issue_key, function(description, err)
				if err ~= nil then
					footer.notify("warn", string.format("Failed loading description for %s", issue_key), 1200)
					open_issue_editor("")
					return
				end

				footer.notify("success", string.format("Loaded description for %s...", issue_key), 1200)
				if type(description) == "table" then
					open_issue_editor(adf.to_markdown(description))
					return
				end

				open_issue_editor("")
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
					done({ changed_issue_key = nil, message = "Search cancelled" }, nil)
					return
				end

				local query = vim.trim(tostring(input))
				if query == "" then
					done({ changed_issue_key = nil, message = "Search query cannot be empty" }, nil)
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
				done({ changed_issue_key = nil, message = "Search view opened" }, nil)
			end)
		end,
	},
	{
		id = "create_issue",
		label = "Create Issue",
		is_available = function()
			return true
		end,
		run = function(_, done)
			---@param project string
			local function run_create_issue(project)
				open_issue_ui({
					summary = "",
					description = nil,
					assignee = nil,
					reporter = jira_state.current_user,
					project = project,
					issue_key = nil,
					issue_type = nil,
				}, function(fields, submit_done)
					local issue_type = fields.issue_type
					local issue_type_name = type(issue_type) == "table" and tostring(issue_type.name or "") or ""
					local issue_type_id = type(issue_type) == "table" and tostring(issue_type.id or "") or ""
					local api_fields = {
						project = { key = fields.project },
						summary = fields.summary,
					}

					if issue_type_id ~= "" then
						api_fields.issuetype = { id = issue_type_id }
					elseif issue_type_name ~= "" then
						api_fields.issuetype = { name = issue_type_name }
					else
						submit_done(false, "Issue type is required")
						done(nil, "Issue type is required")
						return
					end

					if fields.description then
						api_fields.description = fields.description
					end

					if fields.assignee and fields.assignee.account_id then
						api_fields.assignee = { id = fields.assignee.account_id }
					end

					issues_api.create_issue(api_fields, function(result, err)
						if err then
							submit_done(false, err)
							done(nil, err)
							return
						end

						if result and result.key then
							footer.notify("success", string.format("Created %s", result.key), 2000)
							submit_done(true, nil)
							done(
								{ changed_issue_key = result.key, message = string.format("Created %s", result.key) },
								nil
							)
							return
						end

						submit_done(false, "Invalid response")
						done(nil, "Invalid response")
					end)
				end)
			end

			local projects = get_unique_projects()
			if #projects == 0 then
				done(nil, "No projects configured in views")
				return
			end

			if #projects == 1 then
				run_create_issue(projects[1])
				return
			end

			vim.ui.select(projects, {
				prompt = "Select project",
				kind = "atlas_jira_projects",
			}, function(selected)
				if not selected then
					done({ changed_issue_key = nil, message = "Create issue cancelled" }, nil)
					return
				end

				run_create_issue(selected)
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
