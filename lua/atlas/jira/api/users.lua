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

function M.assign_issue(issue_key, account_id, callback) end

return M
