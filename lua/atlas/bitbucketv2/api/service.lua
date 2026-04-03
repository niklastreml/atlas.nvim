local M = {}

local config = require("atlas.config")
local logger = require("atlas.core.logger")
local http = require("atlas.core.http")
local memory_cache = require("atlas.core.memory_cache")

local API_BASE = "https://api.bitbucket.org/2.0"

---@return string, string, string|nil
function M.get_auth()
	local bb = (config.options and config.options.bitbucket) or {}
	local user = tostring(bb.user or "")
	local token = tostring(bb.token or "")

	if not user or user == "" or not token or token == "" then
		return "", "", "Missing Bitbucket credentials in config (bitbucket.user / bitbucket.token)"
	end

	return user, token, nil
end

---@param user string
---@param token string
---@return table<string, string>
function M.build_headers(user, token)
	local auth = vim.base64.encode(string.format("%s:%s", user or "", token or ""))
	return {
		Authorization = "Basic " .. auth,
		["Content-Type"] = "application/json",
		Accept = "application/json",
	}
end

---@return string
function M.base_url()
	return API_BASE
end

---@param endpoint string
---@return string
function M.url(endpoint)
	if endpoint:sub(1, 1) ~= "/" then
		endpoint = "/" .. endpoint
	end
	return API_BASE .. endpoint
end

---@return number
function M.cache_ttl()
	return ((config.options.bitbucket and config.options.bitbucket.cache_ttl) or 300)
end

function M.clear_memory_cache()
	memory_cache.clear_all()
end

---@param pr BitbucketPR
function M.clear_pullrequest_memory_cache(pr)
	local workspace = tostring(pr.repo.workspace or "")
	local repo = tostring(pr.repo.repo or "")
	local pr_id = tostring(pr.id or "")
	if workspace ~= "" and repo ~= "" and pr_id ~= "" then
		memory_cache.delete(string.format("bitbucket:mem:pr_detail:%s/%s/%s", workspace, repo, pr_id))
	end

	local links = pr.links or {}
	local commits_url = tostring(links.commits or "")
	local diffstat_url = tostring(links.diffstat or "")
	local diff_url = tostring(links.diff or "")
	local comments_url = tostring(links.comments or "")
	local activity_url = tostring(links.activity or "")

	if commits_url ~= "" then
		memory_cache.delete("bitbucket:mem:pr_commits:" .. commits_url)
	end
	if diffstat_url ~= "" then
		memory_cache.delete("bitbucket:mem:pr_diffstat:" .. diffstat_url)
	end
	if diff_url ~= "" then
		memory_cache.delete("bitbucket:mem:pr_diff:" .. diff_url)
	end
	if comments_url ~= "" then
		memory_cache.delete("bitbucket:mem:pr_comments:" .. comments_url)
	end
	if activity_url ~= "" then
		memory_cache.delete("bitbucket:mem:pr_activity:" .. activity_url)
	end
end

---@param result any
---@return string|nil
function M.api_error_message(result)
	if type(result) ~= "table" or result.error == nil then
		return nil
	end
	if type(result.error) == "table" and result.error.message then
		return tostring(result.error.message)
	end
	if type(result.error) == "string" then
		return result.error
	end
	return "Bitbucket API error"
end

---@param method string "GET"|"POST"|"PUT"|"DELETE"
---@param url string Full URL or endpoint
---@param headers table|nil Optional headers (will merge with auth headers)
---@param body string|nil Optional JSON body
---@param callback fun(result: table|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.request(method, url, headers, body, callback)
	local user, token, auth_err = M.get_auth()
	if auth_err then
		callback(nil, auth_err)
		return nil
	end

	local request_headers = M.build_headers(user, token)
	if headers then
		for k, v in pairs(headers) do
			request_headers[k] = v
		end
	end

	-- If url doesn't start with http, treat it as an endpoint
	local full_url = url
	if not url:match("^https?://") then
		full_url = M.url(url)
	end

	logger.loginfo("Bitbucket request", {
		method = method,
		url = full_url,
	})

	return http.curl_request(method, full_url, request_headers, body, function(result, err)
		if err then
			logger.logerror("Bitbucket request failed", {
				method = method,
				url = full_url,
				error = err,
			})
			callback(nil, err)
			return
		end

		if type(result) ~= "table" then
			callback(nil, "Bitbucket response is not a JSON object")
			return
		end

		local api_err = M.api_error_message(result)
		if api_err then
			logger.logerror("Bitbucket API error", {
				method = method,
				url = full_url,
				error = api_err,
			})
			callback(nil, api_err)
			return
		end

		callback(result, nil)
	end)
end

---@param method string "GET"|"POST"|"PUT"|"DELETE"
---@param url string Full URL or endpoint
---@param headers table|nil Optional headers (will merge with auth headers)
---@param body string|nil Optional body
---@param callback fun(text: string|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.request_text(method, url, headers, body, callback)
	local user, token, auth_err = M.get_auth()
	if auth_err then
		callback(nil, auth_err)
		return nil
	end

	local request_headers = M.build_headers(user, token)
	if headers then
		for k, v in pairs(headers) do
			request_headers[k] = v
		end
	end

	-- If url doesn't start with http, treat it as an endpoint
	local full_url = url
	if not url:match("^https?://") then
		full_url = M.url(url)
	end

	return http.curl_text_request(method, full_url, request_headers, body, callback)
end

return M
