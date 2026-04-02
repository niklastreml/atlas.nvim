local M = {}

local service = require("atlas.jira.api.service")
local normalizer = require("atlas.jira.api.normalizer")
local logger = require("atlas.core.logger")

---@param issue_key string
---@param start_at number|nil
---@param max_results number|nil
---@param callback fun(page: JiraCommentPage|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.get_comments_page(issue_key, start_at, max_results, callback)
	if type(issue_key) ~= "string" or issue_key == "" then
		callback(nil, "Missing issue key")
		return nil
	end

	local start = tonumber(start_at) or 0
	local size = tonumber(max_results) or 100

	logger.loginfo("Jira fetch comments page", { issue_key = issue_key, start_at = start, max_results = size })
	local endpoint = string.format("/issue/%s/comment?startAt=%d&maxResults=%d", issue_key, start, size)

	return service.request("GET", endpoint, nil, function(result, err)
		vim.defer_fn(function()
			if err or not result then
				callback(nil, err or "Empty response")
				return
			end

			callback(normalizer.normalize_comments(result), nil)
		end, 400)
	end)
end

function M.add_comment(issue_key, comment, callback) end

function M.edit_comment(issue_key, comment_id, comment, callback) end

return M
