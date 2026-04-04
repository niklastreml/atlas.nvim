local M = {}

local service = require("atlas.jira.api.service")
local normalizer = require("atlas.jira.api.normalizer")
local cache = require("atlas.core.cache")
local logger = require("atlas.core.logger")

local SEARCH_FIELDS = {
	"summary",
	"status",
	"assignee",
	"reporter",
	"parent",
	"priority",
	"issuetype",
	"duedate",
	-- TODO: Probably different in every board, need to make this configurable
	"customfield_10016", --- story points
	"customfield_10003", --- approvers
}

---@param jql string
---@param on_done fun(issues: JiraIssue[]|nil, err: string|nil)
---@param opts { force_load?: boolean }|nil
---@return { job_id: integer, cancel: fun() }|nil
function M.search_issues(jql, on_done, opts)
	opts = opts or {}
	local ttl = service.cache_ttl()
	local cache_key = "jira:search:" .. jql

	if not opts.force_load then
		local cached = cache.get(cache_key)
		if cached and cached.value then
			logger.loginfo("Jira search cache hit", { jql = jql })
			on_done(cached.value, nil)
			return nil
		end
	end

	logger.loginfo("Jira search issues", { jql = jql })

	local all_issues = {}
	local function fetch_page(page_token)
		local data = {
			jql = jql,
			fields = SEARCH_FIELDS,
			nextPageToken = page_token or "",
			maxResults = 100,
		}

		return service.request("POST", "/search/jql", data, function(result, err)
			if err or not result then
				on_done(nil, err or "Empty response")
				return
			end

			local raw_issues = result.issues or {}
			local normalized = normalizer.normalize_issues(raw_issues)
			for _, issue in ipairs(normalized) do
				table.insert(all_issues, issue)
			end

			local next_token = result.nextPageToken
			if next_token and next_token ~= "" and #raw_issues > 0 then
				fetch_page(next_token)
				return
			end

			cache.set(cache_key, all_issues, ttl)
			logger.loginfo("Jira search complete", { jql = jql, count = #all_issues })
			on_done(all_issues, nil)
		end)
	end

	return fetch_page("")
end

---@param issue_key string
---@param callback fun(issue: JiraIssue|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.get_issue(issue_key, callback)
	if type(issue_key) ~= "string" or issue_key == "" then
		callback(nil, "Missing issue key")
		return nil
	end

	logger.loginfo("Jira fetch issue", { issue_key = issue_key })
	local endpoint = string.format("/issue/%s?fields=%s", issue_key, table.concat(SEARCH_FIELDS, ","))

	return service.request("GET", endpoint, nil, function(result, err)
		if err or not result then
			callback(nil, err or "Empty response")
			return
		end

		callback(normalizer.normalize_issue(result), nil)
	end)
end

---@param issue_key string
---@param start_at number|nil
---@param max_results number|nil
---@param on_done fun(page: JiraIssueHistoryPage|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.get_issue_history_page(issue_key, start_at, max_results, on_done)
	if type(issue_key) ~= "string" or issue_key == "" then
		on_done(nil, "Missing issue key")
		return nil
	end

	local start = math.max(0, tonumber(start_at) or 0)
	local size = math.max(1, tonumber(max_results) or 100)

	logger.loginfo("Jira fetch issue history page", {
		issue_key = issue_key,
		start_at = start,
		max_results = size,
	})

	local endpoint = string.format("/issue/%s/changelog?startAt=%d&maxResults=%d", issue_key, start, size)

	return service.request("GET", endpoint, nil, function(result, err)
		if err or not result then
			on_done(nil, err or "Empty response")
			return
		end

		on_done(normalizer.normalize_issue_history_page(result, start, size), nil)
	end)
end

---@param issue_key string
---@param on_done fun(description: any, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.get_issue_description(issue_key, on_done)
	if type(issue_key) ~= "string" or issue_key == "" then
		on_done(nil, "Missing issue key")
		return nil
	end

	logger.loginfo("Jira fetch issue description", { issue_key = issue_key })
	local data = {
		jql = "key = " .. issue_key,
		fields = { "description" },
		maxResults = 1,
	}

	return service.request("POST", "/search/jql", data, function(result, err)
		if err or not result then
			logger.logerror("Jira description fetch failed", {
				issue_key = issue_key,
				error = err or "Empty response",
			})
			on_done(nil, err or "Empty response")
			return
		end

		local first_issue = (result.issues or {})[1]
		local description = first_issue and first_issue.fields and first_issue.fields.description or nil
		logger.loginfo("Jira description fetch complete", {
			issue_key = issue_key,
			has_description = description ~= nil,
		})
		on_done(description, nil)
	end)
end

function M.create_issue(fields, callback)
	if type(callback) ~= "function" then
		return nil
	end

	if type(fields) ~= "table" then
		callback(nil, "Missing fields")
		return nil
	end

	if not fields.summary or fields.summary == "" then
		callback(nil, "Missing summary")
		return nil
	end

	if not fields.project then
		callback(nil, "Missing project")
		return nil
	end

	if not fields.issuetype then
		callback(nil, "Missing issue type")
		return nil
	end

	logger.loginfo("Jira create issue", { summary = fields.summary })

	local payload = { fields = fields }

	return service.request("POST", "/issue", payload, function(result, err)
		if err ~= nil then
			callback(nil, err)
			return
		end

		if not result or not result.key then
			callback(nil, "Invalid response")
			return
		end

		callback({
			key = result.key,
			id = result.id,
			self = result.self,
		}, nil)
	end)
end

---@param issue_key string
---@param fields table
---@param callback fun(ok: boolean, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.update_issue(issue_key, fields, callback)
	if type(callback) ~= "function" then
		return nil
	end

	if type(issue_key) ~= "string" or issue_key == "" then
		callback(false, "Missing issue key")
		return nil
	end

	if type(fields) ~= "table" then
		callback(false, "Missing fields")
		return nil
	end

	logger.loginfo("Jira update issue", { issue_key = issue_key })
	local endpoint = string.format("/issue/%s", issue_key)
	local payload = { fields = fields }

	return service.request("PUT", endpoint, payload, function(_, err)
		if err ~= nil then
			callback(false, err)
			return
		end

		callback(true, nil)
	end)
end

---@class JiraIssueType
---@field id string
---@field name string
---@field description string
---@field subtask boolean

---@param project_key string
---@param callback fun(issue_types: JiraCreateIssueType[]|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.get_create_meta(project_key, callback)
	if type(project_key) ~= "string" or project_key == "" then
		callback(nil, "Missing project key")
		return nil
	end

	local escaped_key = vim.fn.escape(project_key, "&=?")
	local endpoint = string.format("/issue/createmeta?projectKeys=%s&expand=projects.issuetypes", escaped_key)
	logger.loginfo("Jira fetch create metadata", { project_key = project_key })

	return service.request("GET", endpoint, nil, function(result, err)
		if err ~= nil or type(result) ~= "table" then
			callback(nil, err or "Empty response")
			return
		end

		local projects = result.projects
		if type(projects) ~= "table" then
			callback({}, nil)
			return
		end

		local matched_project = nil
		for _, project in ipairs(projects) do
			if type(project) == "table" and tostring(project.key or "") == project_key then
				matched_project = project
				break
			end
		end

		local project = matched_project or projects[1]
		local raw_types = type(project) == "table" and project.issuetypes or nil
		if type(raw_types) ~= "table" then
			callback({}, nil)
			return
		end

		local issue_types = {}
		for _, raw in ipairs(raw_types) do
			if type(raw) == "table" then
				table.insert(issue_types, {
					id = tostring(raw.id or ""),
					name = tostring(raw.name or ""),
					description = tostring(raw.description or ""),
					subtask = raw.subtask == true,
				})
			end
		end

		callback(issue_types, nil)
	end)
end

return M
