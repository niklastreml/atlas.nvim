local M = {}

local config = require("atlas.config")
local service = require("atlas.jira.api.service")
local cache = require("atlas.core.cache")
local logger = require("atlas.core.logger")

---@param callback fun(user: JiraUser|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.get_myself(callback)
	logger.loginfo("Jira fetch current user")

	local cache_key = "jira:myself:" .. (config.options.jira.email or "")
	local cached = cache.get(cache_key)
	if cached and cached.value then
		callback(cached.value, nil)
		return nil
	end

	return service.request("GET", "/myself", nil, function(result, err)
		if err or not result then
			callback(nil, err or "Empty response")
			return
		end

		local user = {
			account_id = tostring(result.accountId or ""),
			display_name = tostring(result.displayName or ""),
			email = tostring(result.emailAddress or ""),
		}

		cache.set(cache_key, user, service.cache_ttl())
		callback(user, nil)
	end)
end

---@param issue_key string
---@param query string|nil
---@param callback fun(users: JiraUser[]|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.get_assignable_users(issue_key, query, callback)
	if type(issue_key) ~= "string" or issue_key == "" then
		callback(nil, "Missing issue key")
		return nil
	end

	local q = tostring(query or "")
	local endpoint = string.format("/user/assignable/search?issueKey=%s&query=%s", issue_key, vim.fn.escape(q, "&=?"))
	logger.loginfo("Jira fetch assignable users", { issue_key = issue_key, query = q })

	return service.request("GET", endpoint, nil, function(result, err)
		if err ~= nil or type(result) ~= "table" then
			callback(nil, err or "Empty response")
			return
		end

		local users = {}
		for _, raw in ipairs(result) do
			if type(raw) == "table" then
				table.insert(users, {
					account_id = tostring(raw.accountId or ""),
					display_name = tostring(raw.displayName or ""),
					email = tostring(raw.emailAddress or ""),
				})
			end
		end

		callback(users, nil)
	end)
end

---@param issue_key string
---@param account_id string|nil
---@param callback fun(ok: boolean, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.assign_issue(issue_key, account_id, callback)
	if type(issue_key) ~= "string" or issue_key == "" then
		callback(false, "Missing issue key")
		return nil
	end

	local normalized_account_id = nil
	if type(account_id) == "string" and account_id ~= "" then
		normalized_account_id = account_id
	end

	logger.loginfo("Jira assign issue", { issue_key = issue_key, unassign = normalized_account_id == nil })
	local endpoint = string.format("/issue/%s/assignee", issue_key)
	local payload = { accountId = normalized_account_id or vim.NIL }

	return service.request("PUT", endpoint, payload, function(_, err)
		if err ~= nil then
			callback(false, err)
			return
		end

		callback(true, nil)
	end)
end

---@param issue_key string
---@param account_id string
---@param callback fun(ok: boolean, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.change_reporter(issue_key, account_id, callback)
	if type(issue_key) ~= "string" or issue_key == "" then
		callback(false, "Missing issue key")
		return nil
	end

	if type(account_id) ~= "string" or account_id == "" then
		callback(false, "Missing account id")
		return nil
	end

	logger.loginfo("Jira change reporter", { issue_key = issue_key })
	local endpoint = string.format("/issue/%s", issue_key)
	local payload = {
		fields = {
			reporter = {
				accountId = account_id,
			},
		},
	}

	return service.request("PUT", endpoint, payload, function(_, err)
		if err ~= nil then
			callback(false, err)
			return
		end

		callback(true, nil)
	end)
end

return M
