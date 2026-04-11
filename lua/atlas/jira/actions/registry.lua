local M = {}

local transitions_api = require("atlas.jira.api.transitions")
local users_api = require("atlas.jira.api.users")
local issues_api = require("atlas.jira.api.issues")
local projects_api = require("atlas.jira.api.projects")
local jira_state = require("atlas.jira.state")
local config = require("atlas.config")
local issue_editor = require("atlas.jira.ui.issue")
local markdown_editor = require("atlas.ui.popups.markdown_editor")
local adf = require("atlas.jira.converted.adf")
local template_store = require("atlas.jira.templates")
local footer = require("atlas.ui.components.footer")
local async_picker = require("atlas.ui.components.async_picker")
local icons = require("atlas.ui.utils.icons")

---@class JiraActionContext
---@field issue JiraIssue|nil
---@field source "panel"|"main"|nil
---@field description string|nil

---@class JiraActionResult
---@field changed_issue_key string|nil
---@field message string|nil

---@class JiraActionDef
---@field id JiraActionId
---@field label string
---@field is_available fun(ctx: JiraActionContext): boolean, string|nil
---@field run fun(ctx: JiraActionContext, done: fun(result: JiraActionResult|nil, err: string|nil))

---@param ctx JiraActionContext
---@return boolean
---@return string|nil
local function has_issue_key(ctx)
	if ctx.issue == nil then
		return false, "No issue selected"
	end

	if tostring(ctx.issue.key or "") == "" then
		return false, "Selected issue is missing key"
	end

	return true, nil
end

---@param opts IssueFields
---@param on_submit fun(fields: IssueFields, submit_done: fun(ok: boolean, err: string|nil))
local function open_issue_ui(opts, on_submit)
	issue_editor.open(function(fields, submit_done)
		on_submit(fields, submit_done or function() end)
	end, opts)
end

---@param initial_markdown string|nil
---@param done fun(result: JiraActionResult|nil, err: string|nil)
local function open_create_template_editor(initial_markdown, done)
	--- Just in case, to prevent multiple calls to done callback.
	--- You could create an issue, press save, close the editor and enter the name after closing the picker, which would trigger the done callback twice.
	local finalized = false
	local function finish(result, err)
		if finalized then
			return
		end
		finalized = true
		done(result, err)
	end

	markdown_editor.open({
		key = string.format("template_new_%d", vim.loop.hrtime()),
		title = " New Issue Template ",
		initial_text = tostring(initial_markdown or ""),
		on_save = function(text)
			local markdown = tostring(text or "")

			vim.ui.input({
				prompt = "Template name: ",
			}, function(name_input)
				if name_input == nil then
					finish({ changed_issue_key = nil, message = nil }, nil)
					return
				end

				local name = vim.trim(tostring(name_input))
				if name == "" then
					finish(nil, "Template name is required")
					return
				end

				local ok, write_err, existed, normalized_name =
					template_store.write(name, markdown, { overwrite = false })
				if ok then
					finish({
						changed_issue_key = nil,
						message = string.format("Created template %s", tostring(normalized_name or name)),
					}, nil)
					return
				end

				if existed then
					vim.ui.input({
						prompt = string.format(
							'Template "%s" exists. Overwrite? [y/N]: ',
							tostring(normalized_name or name)
						),
					}, function(confirm)
						if confirm == nil then
							finish({ changed_issue_key = nil, message = nil }, nil)
							return
						end

						local normalized = vim.trim(tostring(confirm)):lower()
						if normalized ~= "y" and normalized ~= "yes" then
							finish({ changed_issue_key = nil, message = nil }, nil)
							return
						end

						local overwrite_ok, overwrite_err, _, final_name =
							template_store.write(name, markdown, { overwrite = true })
						if not overwrite_ok then
							finish(nil, overwrite_err or "Failed to overwrite template")
							return
						end

						finish({
							changed_issue_key = nil,
							message = string.format(
								"Updated template %s",
								tostring(final_name or normalized_name or name)
							),
						}, nil)
					end)
					return
				end

				finish(nil, write_err or "Failed to create template")
			end)
		end,
		on_cancel = function()
			finish({ changed_issue_key = nil, message = nil }, nil)
		end,
	})
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
			local issue_project_key = issue.project and issue.project.key or nil
			local current_status = tostring(issue.status or "")

			---@type AsyncPickerItem[]|nil
			local all_items = nil

			local status_category_icons = {
				new = icons.entity("pending"),
				indeterminate = icons.entity("info"),
				done = icons.entity("success"),
			}

			async_picker.open({
				title = string.format("Transition %s", issue_key),
				prompt = "Filter transitions",
				debounce_ms = 0,
				identifier = "jira_transitions:" .. issue_key,
				format_item = function(item)
					local transition = item.value
					local category = type(transition) == "table" and transition.to_status_category or nil
					local icon = category and status_category_icons[category] or icons.fallback()
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

					transitions_api.get_transitions(issue_key, function(page, err)
						if err ~= nil or page == nil then
							fetch_done(nil, err or "Failed to load transitions")
							return
						end

						all_items = {}
						for _, transition in ipairs(page.transitions or {}) do
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
			local current_assignee = type(issue.assignee) == "table" and issue.assignee.display_name or ""
			local current_assignee_key = vim.trim(current_assignee):lower()

			local function to_picker_items(users)
				local items = {}
				local current_user_account_id = jira_state.current_user and jira_state.current_user.account_id or nil
				local seen_current_user = false
				local current_user_item = nil
				if
					current_assignee_key ~= ""
					and current_assignee_key ~= "unassigned"
					and current_assignee_key ~= "none"
				then
					table.insert(items, {
						id = "__unassign__",
						label = "Unassign",
						value = { account_id = nil, display_name = "Unassign" },
					})
				end

				for _, user in ipairs(users or {}) do
					local user_name = tostring((user and user.display_name) or "")
					local user_account_id = type(user) == "table" and user.account_id or nil
					if vim.trim(user_name):lower() ~= current_assignee_key then
						local item = {
							id = user.account_id or "",
							label = user.display_name or "",
							value = user,
						}
						if current_user_account_id and user_account_id == current_user_account_id then
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
							label = jira_state.current_user.display_name,
							value = jira_state.current_user,
						}
					end
					if current_user_item then
						table.insert(items, 1, current_user_item)
					end
				end
				return items
			end

			local function open_assign_picker()
				async_picker.open({
					title = string.format("Assign %s", issue_key),
					prompt = "Search users",
					initial_items = to_picker_items({}),
					debounce_ms = 250,
					cache_ttl_ms = 60000,
					identifier = "jira_users:" .. (issue_project_key or ""),
					format_item = function(item)
						if item.id == "__unassign__" then
							return item.label
						end
						return string.format("%s %s", icons.entity("user"), item.label or "")
					end,
					fetch_on_open = false,
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
					end,
					on_cancel = function()
						done({ changed_issue_key = nil, message = "Assign cancelled" }, nil)
					end,
				})
			end

			open_assign_picker()
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
			local current_reporter = type(issue.reporter) == "string" and issue.reporter or ""
			local current_reporter_key = vim.trim(current_reporter):lower()

			local function to_picker_items(users)
				local items = {}
				for _, user in ipairs(users or {}) do
					local user_name = tostring((user and user.display_name) or "")
					if vim.trim(user_name):lower() ~= current_reporter_key then
						table.insert(items, {
							id = user.account_id or "",
							label = user.display_name or "",
							value = user,
						})
					end
				end
				return items
			end

			local function open_reporter_picker()
				async_picker.open({
					title = string.format("Reporter for %s", issue_key),
					prompt = "Search users",
					initial_items = {},
					debounce_ms = 250,
					cache_ttl_ms = 60000,
					format_item = function(item)
						return string.format("%s %s", icons.entity("user"), item.label or "")
					end,
					fetch_on_open = false,
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
					end,
					on_cancel = function()
						done({ changed_issue_key = nil, message = "Reporter change cancelled" }, nil)
					end,
				})
			end

			open_reporter_picker()
		end,
	},
	{
		id = "delete_issue",
		label = "Delete Issue",
		is_available = has_issue_key,
		run = function(ctx, done)
			local issue = ctx.issue
			if not has_issue_key(ctx) or issue == nil then
				done(nil, "No issue selected")
				return
			end

			local issue_key = issue.key
			vim.ui.input({
				prompt = string.format("Delete issue %s? [y/N]: ", issue_key),
			}, function(input)
				if input == nil then
					done({ changed_issue_key = nil, message = "Delete cancelled" }, nil)
					return
				end

				local normalized = vim.trim(tostring(input)):lower()
				if normalized ~= "y" and normalized ~= "yes" then
					done({ changed_issue_key = nil, message = "Delete cancelled" }, nil)
					return
				end

				footer.notify("loading", string.format("Deleting %s...", issue_key))
				issues_api.delete_issue(issue_key, function(ok, err)
					if not ok then
						footer.notify("error", err or "Delete failed")
						done(nil, err or "Delete failed")
						return
					end

					footer.notify("success", string.format("Deleted %s", issue_key), 1200)
					--- After deletion for now simply refresh the whole current view
					require("atlas.jira.ui.controller").refresh_current_view(function()
						done({ changed_issue_key = nil, message = string.format("Deleted %s", issue_key) }, nil)
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
		id = "search_query_issue",
		label = "Search Issue",
		is_available = function()
			return true, nil
		end,
		run = function(_, done)
			async_picker.open({
				title = "Search Query Ticket",
				prompt = "Search tickets",
				debounce_ms = 200,
				identifier = "jira_issue_picker_search",
				cache_ttl_ms = 30000,
				fetch_on_open = true,
				format_item = function(item)
					return string.format("%s %s", icons.jira_icon("story"), item.label)
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

						---@type AsyncPickerItem[]
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

					require("atlas.jira.ui.controller").switch_view(search_view)
					done({ changed_issue_key = issue_key, message = string.format("Opened %s", issue_key) }, nil)
				end,
				on_cancel = function()
					done({ changed_issue_key = nil, message = "Search cancelled" }, nil)
				end,
			})
		end,
	},
	{
		id = "search_issues",
		label = "Search JQL",
		is_available = function()
			return true, nil
		end,
		run = function(_, done)
			require("atlas.jira.completion.search").open_cmdline()
			done({ changed_issue_key = nil, message = "Type query and press Enter" }, nil)
		end,
	},
	{
		id = "create_issue",
		label = "Create Issue",
		is_available = function()
			return true, nil
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

			---@type AsyncPickerItem[]|nil
			local all_items = nil

			async_picker.open({
				title = "Create Issue",
				prompt = "Select project",
				debounce_ms = 0,
				identifier = "jira_creatable_projects",
				format_item = function(item)
					local project = item.value
					local category_name = project.category and project.category.name or ""
					if category_name ~= "" then
						return string.format(
							"%s %s - %s (%s)",
							icons.jira_icon("jira.entity.project"),
							item.label,
							project.name,
							category_name
						)
					end
					return string.format("%s %s - %s", icons.jira_icon("jira.entity.project"), item.label, project.name)
				end,
				fetch = function(fetch_ctx, fetch_done)
					-- Already loaded — filter locally
					if all_items then
						local query = vim.trim(fetch_ctx.query):lower()
						if query == "" then
							fetch_done(all_items, nil)
							return
						end
						local filtered = {}
						for _, item in ipairs(all_items) do
							local project = item.value
							local haystack = (
								item.label
								.. " "
								.. (project.name or "")
								.. " "
								.. (project.category and project.category.name or "")
							):lower()
							if haystack:find(query, 1, true) then
								table.insert(filtered, item)
							end
						end
						fetch_done(filtered, nil)
						return
					end

					-- First call: fetch projects + permissions
					projects_api.get_projects({ maxResults = 50, total = 2, status = "live" }, function(groups, err)
						if fetch_ctx.signal.cancelled then
							return
						end
						if err ~= nil or groups == nil then
							fetch_done(nil, err or "Failed to load projects")
							return
						end

						---@type JiraProject[]
						local projects = {}
						for _, group in ipairs(groups) do
							for _, project in ipairs(group.projects or {}) do
								table.insert(projects, project)
							end
						end

						local project_ids = {}
						for _, project in ipairs(projects) do
							local project_id = tonumber(project.id)
							if project_id ~= nil then
								table.insert(project_ids, project_id)
							end
						end

						users_api.get_permissions_bulk({
							permissions = { "CREATE_ISSUES" },
							project_ids = project_ids,
						}, function(permission_map, permission_err)
							if fetch_ctx.signal.cancelled then
								return
							end
							if permission_err ~= nil or permission_map == nil then
								fetch_done(nil, permission_err or "Failed to load project permissions")
								return
							end

							local allowed_map = permission_map.CREATE_ISSUES or {}
							all_items = {}
							for _, project in ipairs(projects) do
								local project_id = tonumber(project.id)
								if project_id ~= nil and allowed_map[project_id] == true then
									table.insert(all_items, {
										id = tostring(project.id or ""),
										label = tostring(project.key or ""),
										value = project,
									})
								end
							end

							fetch_done(all_items, nil)
						end)
					end)
				end,
				on_select = function(item)
					run_create_issue(item.value.key)
				end,
				on_cancel = function()
					footer.notify("info", "Create issue cancelled", 1200)
					done({ changed_issue_key = nil, message = "Create issue cancelled" }, nil)
				end,
			})
		end,
	},
	{
		id = "create_template",
		label = "Create Issue Template",
		is_available = function()
			return true, nil
		end,
		run = function(ctx, done)
			open_create_template_editor(ctx.description, done)
		end,
	},
	{
		id = "manage_templates",
		label = "Manage Issue Templates",
		is_available = function()
			return true, nil
		end,
		run = function(ctx, done)
			local options = {
				{ id = "create", label = "Create template" },
				{ id = "edit", label = "Edit template" },
			}

			vim.ui.select(options, {
				prompt = "Templates",
				kind = "atlas_jira_template_actions",
				format_item = function(item)
					return tostring((item and item.label) or "")
				end,
			}, function(choice)
				if choice == nil then
					done({ changed_issue_key = nil, message = "Template action cancelled" }, nil)
					return
				end

				if choice.id == "create" then
					open_create_template_editor(ctx and ctx.description or nil, done)
					return
				end

				local templates, list_err = template_store.list()
				if list_err ~= nil then
					done(nil, list_err)
					return
				end

				if templates == nil or #templates == 0 then
					done({ changed_issue_key = nil, message = "No templates found" }, nil)
					return
				end

				vim.ui.select(templates, {
					prompt = "Edit template",
					kind = "atlas_jira_templates",
					format_item = function(item)
						return tostring((item and item.name) or "")
					end,
				}, function(selected)
					if selected == nil then
						done({ changed_issue_key = nil, message = "Template edit cancelled" }, nil)
						return
					end

					local template_name = tostring(selected.name or "")
					if template_name == "" then
						done(nil, "Invalid template selected")
						return
					end

					local content, read_err = template_store.read(template_name)
					if read_err ~= nil then
						done(nil, read_err)
						return
					end

					local finalized = false
					local function finish(result, err)
						if finalized then
							return
						end
						finalized = true
						done(result, err)
					end

					local key = ("template_" .. template_name):gsub("[^%w%-_]+", "_")
					markdown_editor.open({
						key = key,
						title = string.format(" Template: %s ", template_name),
						initial_text = content,
						actions = {
							{
								key = "<C-d>",
								description = "delete",
								callback = function(editor_ctx)
									vim.ui.input({
										prompt = string.format('Delete template "%s"? [y/N]: ', template_name),
									}, function(confirm)
										if confirm == nil then
											return
										end

										local normalized = vim.trim(tostring(confirm)):lower()
										if normalized ~= "y" and normalized ~= "yes" then
											return
										end

										local deleted, delete_err = template_store.delete(template_name)
										if not deleted then
											finish(nil, delete_err or "Failed to delete template")
											return
										end

										editor_ctx.close()
										finish({
											changed_issue_key = nil,
											message = string.format("Deleted template %s", template_name),
										}, nil)
									end)
								end,
							},
						},
						on_save = function(text)
							local ok, write_err = template_store.write(template_name, text, { overwrite = true })
							if not ok then
								finish(nil, write_err or "Failed to update template")
								return
							end

							finish({
								changed_issue_key = nil,
								message = string.format("Updated template %s", template_name),
							}, nil)
						end,
						on_cancel = function()
							finish({ changed_issue_key = nil, message = "Template edit cancelled" }, nil)
						end,
					})
				end)
			end)
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

			local base_url = tostring(((config.options and config.options.jira) or {}).base_url or ""):gsub("/$", "")
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

			local base_url = tostring(((config.options and config.options.jira) or {}).base_url or ""):gsub("/$", "")
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

---@param id JiraActionId|string
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
