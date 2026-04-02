local M = {}

local service = require("atlas.jira.api.service")
local normalizer = require("atlas.jira.api.normalizer")
local logger = require("atlas.core.logger")

---@param issue_key string
---@param callback fun(page: JiraIssueTransitionPage|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.get_transitions(issue_key, callback)
	if type(issue_key) ~= "string" or issue_key == "" then
		callback(nil, "Missing issue key")
		return nil
	end

	logger.loginfo("Jira fetch transitions", { issue_key = issue_key })
	local endpoint = string.format("/issue/%s/transitions", issue_key)

	return service.request("GET", endpoint, nil, function(result, err)
		if err or not result then
			callback(nil, err or "Empty response")
			return
		end

		callback(normalizer.normalize_transitions(result), nil)
	end)
end

---@param issue_key string
---@param transition_id string|number
---@param callback fun(ok: boolean, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.transition_issue(issue_key, transition_id, callback)
	if type(issue_key) ~= "string" or issue_key == "" then
		callback(false, "Missing issue key")
		return nil
	end

	local id = tostring(transition_id or "")
	if id == "" then
		callback(false, "Missing transition id")
		return nil
	end

	logger.loginfo("Jira transition issue", { issue_key = issue_key, transition_id = id })
	local endpoint = string.format("/issue/%s/transitions", issue_key)
	local payload = {
		transition = { id = id },
	}

	return service.request("POST", endpoint, payload, function(_, err)
		if err ~= nil then
			callback(false, err)
			return
		end

		callback(true, nil)
	end)
end

return M
