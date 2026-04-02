local M = {}

local service = require("atlas.jira.api.service")
local normalizer = require("atlas.jira.api.normalizer")
local logger = require("atlas.core.logger")
local markdown = require("atlas.jira.converted.markdown")

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
		if err or not result then
			callback(nil, err or "Empty response")
			return
		end

		callback(normalizer.normalize_comments(result), nil)
	end)
end

---@param issue_key string
---@param comment string
---@param opts { parent_id?: string|number }|fun(comment: JiraComment|nil, err: string|nil)|nil
---@param callback fun(comment: JiraComment|nil, err: string|nil)|nil
---@return { job_id: integer, cancel: fun() }|nil
function M.add_comment(issue_key, comment, opts, callback)
	if type(opts) == "function" then
		callback = opts
		opts = nil
	end

	if type(callback) ~= "function" then
		return nil
	end

	if type(issue_key) ~= "string" or issue_key == "" then
		callback(nil, "Missing issue key")
		return nil
	end

	local body = type(comment) == "string" and comment or ""
	if vim.trim(body) == "" then
		callback(nil, "Comment cannot be empty")
		return nil
	end

	logger.loginfo("Jira add comment", { issue_key = issue_key })
	local endpoint = string.format("/issue/%s/comment", issue_key)
	local payload = {
		body = markdown.to_adf(body),
	}

	local parent_id = opts and opts.parent_id or nil
	if parent_id ~= nil then
		local pid = tostring(parent_id)
		if pid ~= "" then
			payload.parentId = pid
		end
	end

	return service.request("POST", endpoint, payload, function(result, err)
		if err or not result then
			callback(nil, err or "Empty response")
			return
		end

		local page = normalizer.normalize_comments({ comments = { result } })
		callback(page.comments[1], nil)
	end)
end

function M.edit_comment(issue_key, comment_id, comment, callback) end

---@param issue_key string
---@param comment_id string|number
---@param callback fun(ok: boolean, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.delete_comment(issue_key, comment_id, callback)
	if type(issue_key) ~= "string" or issue_key == "" then
		callback(false, "Missing issue key")
		return nil
	end

	local id = tostring(comment_id or "")
	if id == "" then
		callback(false, "Missing comment id")
		return nil
	end

	logger.loginfo("Jira delete comment", { issue_key = issue_key, comment_id = id })
	local endpoint = string.format("/issue/%s/comment/%s", issue_key, id)

	return service.request("DELETE", endpoint, nil, function(_, err)
		if err ~= nil then
			callback(false, err)
			return
		end
		callback(true, nil)
	end)
end

return M
