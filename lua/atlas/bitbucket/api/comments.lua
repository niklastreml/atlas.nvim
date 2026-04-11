local M = {}

local service = require("atlas.bitbucket.api.service")
local pr_normalizer = require("atlas.bitbucket.api.pr_normalizer")

---@class BitbucketCommentInlineInput
---@field from number|nil
---@field to number|nil
---@field start_from number|nil
---@field start_to number|nil
---@field path string|nil

---@param raw string
---@param opts? { parent_id?: number|string|nil, inline?: BitbucketCommentInlineInput|nil }
---@return string
local function encode_comment_payload(raw, opts)
	opts = opts or {}
	local payload = {
		content = {
			raw = tostring(raw or ""),
		},
	}

	if opts.parent_id ~= nil then
		payload.parent = { id = tonumber(opts.parent_id) or opts.parent_id }
	end

	if type(opts.inline) == "table" then
		payload.inline = {
			from = opts.inline.from,
			to = opts.inline.to,
			start_from = opts.inline.start_from,
			start_to = opts.inline.start_to,
			path = opts.inline.path,
		}
	end

	return vim.json.encode(payload)
end

---@param comments_url string
---@param opts? { force_load?: boolean, pagelen?: number }
---@param on_done fun(comments: BitbucketPRComments|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.fetch_comments(comments_url, opts, on_done)
	opts = opts or {}

	if type(comments_url) ~= "string" or comments_url == "" then
		on_done(nil, "Missing Bitbucket comments URL")
		return nil
	end

	local sep = comments_url:find("?") and "&" or "?"
	local url = string.format("%s%spagelen=%d", comments_url, sep, tonumber(opts.pagelen) or 100)
	local key = "bitbucket:pr:comments:" .. url
	if opts.force_load ~= true then
		local cached, ok = service.get_cache(key)
		if ok then
			on_done(cached, nil)
			return nil
		end
	end

	return service.request("GET", url, nil, nil, function(result, err)
		if err then
			on_done(nil, err)
			return
		end

		local comments = pr_normalizer.pr_comments(result)
		service.set_cache(key, comments, service.cache_ttl())
		on_done(comments, nil)
	end)
end

---@param comments_url string
---@param raw string
---@param opts? { inline?: BitbucketCommentInlineInput|nil }
---@param on_done fun(comment: BitbucketPRCommentEntry|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.create_comment(comments_url, raw, opts, on_done)
	if type(comments_url) ~= "string" or comments_url == "" then
		on_done(nil, "Missing Bitbucket comments URL")
		return nil
	end

	local body = encode_comment_payload(raw, { inline = opts and opts.inline or nil })
	return service.request("POST", comments_url, nil, body, function(result, err)
		if err then
			on_done(nil, err)
			return
		end

		local normalized = pr_normalizer.pr_comments({ values = { result } })
		local entries = (normalized or {}).entries or {}
		on_done(entries[1] or nil, nil)
	end)
end

---@param comments_url string
---@param parent_comment_id number|string
---@param raw string
---@param opts? { inline?: BitbucketCommentInlineInput|nil }
---@param on_done fun(comment: BitbucketPRCommentEntry|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.reply_comment(comments_url, parent_comment_id, raw, opts, on_done)
	if type(comments_url) ~= "string" or comments_url == "" then
		on_done(nil, "Missing Bitbucket comments URL")
		return nil
	end

	if parent_comment_id == nil or tostring(parent_comment_id) == "" then
		on_done(nil, "Missing parent comment id")
		return nil
	end

	local body = encode_comment_payload(raw, {
		parent_id = parent_comment_id,
		inline = opts and opts.inline or nil,
	})

	return service.request("POST", comments_url, nil, body, function(result, err)
		if err then
			on_done(nil, err)
			return
		end

		local normalized = pr_normalizer.pr_comments({ values = { result } })
		local entries = (normalized or {}).entries or {}
		on_done(entries[1] or nil, nil)
	end)
end

---@param comment_self_url string
---@param raw string
---@param opts? { inline?: BitbucketCommentInlineInput|nil }
---@param on_done fun(comment: BitbucketPRCommentEntry|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.update_comment(comment_self_url, raw, opts, on_done)
	if type(comment_self_url) ~= "string" or comment_self_url == "" then
		on_done(nil, "Missing Bitbucket comment URL")
		return nil
	end

	local body = encode_comment_payload(raw, { inline = opts and opts.inline or nil })
	return service.request("PUT", comment_self_url, nil, body, function(result, err)
		if err then
			on_done(nil, err)
			return
		end

		local normalized = pr_normalizer.pr_comments({ values = { result } })
		local entries = (normalized or {}).entries or {}
		on_done(entries[1] or nil, nil)
	end)
end

---@param comment_self_url string
---@param on_done fun(result: table|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.delete_comment(comment_self_url, on_done)
	if type(comment_self_url) ~= "string" or comment_self_url == "" then
		on_done(nil, "Missing Bitbucket comment URL")
		return nil
	end

	return service.request("DELETE", comment_self_url, nil, nil, on_done)
end

---@param workspace string
---@param repo string
---@param pr_id string|number
---@param opts? { force_load?: boolean, pagelen?: number }
---@param on_done fun(tasks: BitbucketPRTasks|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.fetch_tasks(workspace, repo, pr_id, opts, on_done)
	opts = opts or {}

	local ws = tostring(workspace or "")
	local rp = tostring(repo or "")
	local id = tostring(pr_id or "")
	if ws == "" or rp == "" or id == "" then
		on_done(nil, "Missing Bitbucket PR task endpoint params")
		return nil
	end

	local endpoint = string.format("/repositories/%s/%s/pullrequests/%s/tasks", ws, rp, id)
	local sep = endpoint:find("?") and "&" or "?"
	local url = string.format("%s%spagelen=%d", endpoint, sep, tonumber(opts.pagelen) or 100)
	local key = string.format("bitbucket:pr:tasks:%s/%s/%s:%d", ws, rp, id, tonumber(opts.pagelen) or 100)
	if opts.force_load ~= true then
		local cached, ok = service.get_cache(key)
		if ok then
			on_done(cached, nil)
			return nil
		end
	end

	return service.request("GET", url, nil, nil, function(result, err)
		if err then
			on_done(nil, err)
			return
		end

		local tasks = pr_normalizer.pr_tasks(result)
		service.set_cache(key, tasks, service.cache_ttl())
		on_done(tasks, nil)
	end)
end

---@param task_url string
---@param opts { state?: "RESOLVED"|"UNRESOLVED"|string, content_raw?: string }|nil
---@param on_done fun(task: BitbucketPRTask|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.update_task(task_url, opts, on_done)
	opts = opts or {}

	local url = tostring(task_url or "")
	if url == "" then
		on_done(nil, "Missing Bitbucket task URL")
		return nil
	end

	local payload = {}
	if type(opts.content_raw) == "string" and opts.content_raw ~= "" then
		payload.content = { raw = opts.content_raw }
	end
	if type(opts.state) == "string" and opts.state ~= "" then
		payload.state = opts.state
	end

	local body = vim.json.encode(payload)
	return service.request("PUT", url, nil, body, function(result, err)
		if err then
			on_done(nil, err)
			return
		end

		local normalized = pr_normalizer.pr_tasks({ values = { result } })
		local entries = (normalized or {}).entries or {}
		on_done(entries[1] or nil, nil)
	end)
end

---@param task_url string
---@param on_done fun(result: table|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.delete_task(task_url, on_done)
	local url = tostring(task_url or "")
	if url == "" then
		on_done(nil, "Missing Bitbucket task URL")
		return nil
	end

	return service.request("DELETE", url, nil, nil, on_done)
end

---@param workspace string
---@param repo string
---@param pr_id string|number
---@param raw string
---@param opts? { comment_id?: number|string|nil }
---@param on_done fun(task: BitbucketPRTask|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.create_task(workspace, repo, pr_id, raw, opts, on_done)
	opts = opts or {}

	local ws = tostring(workspace or "")
	local rp = tostring(repo or "")
	local id = tostring(pr_id or "")
	if ws == "" or rp == "" or id == "" then
		on_done(nil, "Missing Bitbucket PR task endpoint params")
		return nil
	end

	local endpoint = string.format("/repositories/%s/%s/pullrequests/%s/tasks", ws, rp, id)
	local payload = {
		content = { raw = tostring(raw or "") },
	}
	if opts.comment_id ~= nil and tostring(opts.comment_id) ~= "" then
		payload.comment = { id = tonumber(opts.comment_id) or opts.comment_id }
	end

	local body = vim.json.encode(payload)
	return service.request("POST", endpoint, nil, body, function(result, err)
		if err then
			on_done(nil, err)
			return
		end

		local normalized = pr_normalizer.pr_tasks({ values = { result } })
		local entries = (normalized or {}).entries or {}
		on_done(entries[1] or nil, nil)
	end)
end

return M
