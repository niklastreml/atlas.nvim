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

function M.get_issue(issue_key, callback) end
function M.create_issue(fields, callback) end
function M.update_issue(issue_key, fields, callback) end
function M.get_create_meta(project_key, callback) end

return M
