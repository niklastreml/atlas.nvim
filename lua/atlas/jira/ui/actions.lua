local M = {}

local config = require("atlas.config")
local footer = require("atlas.ui.components.footer")
local issues_api = require("atlas.jira.api.issues")

---@param value string
---@param label string
local function copy_value(value, label)
	if value == "" then
		footer.notify("warn", "Nothing to copy")
		return
	end

	vim.fn.setreg("+", value)
	vim.fn.setreg('"', value)
	footer.notify("info", string.format("Copied %s", label))
end

---@return string
local function jira_base_url()
	local jira = (config.options and config.options.jira) or {}
	local base_url = tostring(jira.base_url or "")
	if base_url == "" then
		return ""
	end

	return (base_url:gsub("/$", ""))
end

---@param issue JiraIssue|nil
---@return string
local function issue_key(issue)
	if type(issue) ~= "table" then
		return ""
	end

	return tostring(issue.key or "")
end

---@param key string
---@return string
local function issue_url_for_key(key)
	local base_url = jira_base_url()
	if base_url == "" or key == "" then
		return ""
	end

	return string.format("%s/browse/%s", base_url, key)
end

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

local function open_create_issue_ui(project)
	require("atlas.jira.ui.issue").open(function(fields, done)
		done = done or function() end

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
				done(false, "Issue type is required")
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
				done(false, err)
				return
			end

			if result and result.key then
				footer.notify("success", string.format("Created %s", result.key), 2000)
				require("atlas.jira.ui.controller").refresh_current_view()
				done(true, nil)
				return
			end

			done(false, "Invalid response")
		end)
	end, {
		summary = "",
		description = nil,
		assignee = nil,
		reporter = nil,
		project = project,
		issue_type = nil,
	})
end

function M.create_issue()
	local projects = get_unique_projects()

	if #projects == 0 then
		footer.notify("warn", "No projects configured in views")
		return
	end

	if #projects == 1 then
		open_create_issue_ui(projects[1])
		return
	end

	vim.ui.select(projects, {
		prompt = "Select project",
		kind = "atlas_jira_projects",
	}, function(selected)
		if not selected then
			return
		end
		open_create_issue_ui(selected)
	end)
end

function M.create_issue_browser()
	local base_url = jira_base_url()
	if base_url == "" then
		footer.notify("warn", "Missing Jira base URL")
		return
	end

	vim.ui.open(string.format("%s/secure/CreateIssue!default.jspa", base_url))
end

---@param issue JiraIssue|nil
function M.browse_issue(issue)
	local key = issue_key(issue)
	if key == "" then
		footer.notify("warn", "No issue selected")
		return
	end

	local url = issue_url_for_key(key)
	if url == "" then
		footer.notify("warn", "No URL found for issue")
		return
	end

	vim.ui.open(url)
end

---@param issue JiraIssue|nil
function M.copy_issue_key(issue)
	copy_value(issue_key(issue), "issue key")
end

---@param issue JiraIssue|nil
function M.copy_issue_url(issue)
	local key = issue_key(issue)
	if key == "" then
		footer.notify("warn", "No issue selected")
		return
	end

	local url = issue_url_for_key(key)
	if url == "" then
		footer.notify("warn", "No URL found for issue")
		return
	end

	copy_value(url, "issue URL")
end

return M
