local M = {}
local config = require("atlas.config")
local normalizer = require("atlas.bitbucket.api.normalizer")
local logger = require("atlas.core.logger")
local cache = require("atlas.core.cache")
local memory_cache = require("atlas.core.memory_cache")
local http = require("atlas.core.http")
local state = require("atlas.bitbucket.state")

local API_BASE = "https://api.bitbucket.org/2.0"

local ENDPOINTS = {
	pullrequests_open = "/repositories/%s/%s/pullrequests?state=%s&pagelen=50",
	pullrequest_detail = "/repositories/%s/%s/pullrequests/%s",
	user_profile = "/user",
	user_workspaces = "/user/workspaces",
	repositories = "/repositories/%s?%ssort=-updated_on&pagelen=50",
}

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

local function build_pullrequests_open_url(workspace, repo)
	return API_BASE .. string.format(ENDPOINTS.pullrequests_open, workspace, repo, state.pr_state)
end

local function build_pullrequest_detail_url(workspace, repo, pr_id)
	return API_BASE .. string.format(ENDPOINTS.pullrequest_detail, workspace, repo, tostring(pr_id))
end

---@param result table
---@return BitbucketPRDiffstat
local function normalize_diffstat(result)
	local entries = {}
	for _, item in ipairs((result and result.values) or {}) do
		local old_file = type(item.old) == "table" and item.old or nil
		local new_file = type(item.new) == "table" and item.new or nil
		table.insert(entries, {
			status = tostring(item.status or ""),
			lines_added = tonumber(item.lines_added) or 0,
			lines_removed = tonumber(item.lines_removed) or 0,
			old_file = old_file and {
				path = tostring(old_file.path or ""),
				type = tostring(old_file.type or ""),
			} or nil,
			new_file = new_file and {
				path = tostring(new_file.path or ""),
				type = tostring(new_file.type or ""),
			} or nil,
		})
	end

	return {
		entries = entries,
		size = tonumber(result and result.size) or #entries,
	}
end

---@param result table
---@return BitbucketPRCommits
local function normalize_commits(result)
	local entries = {}
	for _, item in ipairs((result and result.values) or {}) do
		local hash = tostring(item.hash or "")
		local message = tostring(item.message or (item.summary or {}).raw or "")
		message = message:gsub("\r\n", "\n"):gsub("\n+$", "")

		table.insert(entries, {
			hash = hash,
			short_hash = (hash ~= "" and hash:sub(1, 12)) or "",
			date = tostring(item.date or ""),
			message = message,
			author_name = tostring(((item.author or {}).user or {}).display_name or "Unknown"),
			author_nickname = tostring(((item.author or {}).user or {}).nickname or ""),
			html_url = tostring(((item.links or {}).html or {}).href or ""),
		})
	end

	return {
		entries = entries,
		size = tonumber(result and result.size) or #entries,
	}
end

---@param url string
---@param headers table<string, string>
---@param callback fun(text: string|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
local function curl_text_request(url, headers, callback)
	local header_args = {}
	for key, value in pairs(headers or {}) do
		table.insert(header_args, string.format('-H "%s: %s"', key, value))
	end
	local cmd = string.format('curl -sS -X GET %s "%s"', table.concat(header_args, " "), url)

	local out = {}
	local err_out = {}

	local job_id = vim.fn.jobstart(cmd, {
		on_stdout = function(_, response)
			if response then
				vim.list_extend(out, response)
			end
		end,
		on_stderr = function(_, response)
			if response then
				vim.list_extend(err_out, response)
			end
		end,
		on_exit = function(_, code)
			vim.schedule(function()
				local raw = table.concat(out, "\n")
				local stderr_text = table.concat(err_out, "\n")

				if code ~= 0 then
					local err = "curl exited with code " .. tostring(code)
					if stderr_text ~= "" then
						err = err .. ": " .. stderr_text
					end
					callback(nil, err)
					return
				end

				if raw == "" then
					callback(nil, "Empty response from server")
					return
				end

				callback(raw, nil)
			end)
		end,
	})

	if type(job_id) ~= "number" or job_id <= 0 then
		callback(nil, "Failed to start curl job")
		return nil
	end

	return {
		job_id = job_id,
		cancel = function()
			if job_id and job_id > 0 then
				pcall(vim.fn.jobstop, job_id)
			end
		end,
	}
end

local function build_headers(user, token)
	local auth = vim.base64.encode(string.format("%s:%s", user or "", token or ""))
	return {
		Authorization = "Basic " .. auth,
		["Content-Type"] = "application/json",
		Accept = "application/json",
	}
end

---@param result any
---@return string|nil
local function api_error_message(result)
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

---@return string, string, string|nil
local function get_auth_from_config()
	local bb = (config.options and config.options.bitbucket) or {}
	local user = bb.user
	local token = bb.token

	if not user or user == "" or not token or token == "" then
		return "", "", "Missing Bitbucket credentials in config (bitbucket.user / bitbucket.token)"
	end

	return user, token, nil
end

---@param workspace string
---@param repo string
---@return string
local function cache_key(workspace, repo)
	return string.format("bitbucket:prs:%s/%s", workspace, repo)
end

---@param workspace string
---@param repo string
---@param pullrequests BitbucketPR[]
---@return BitbucketRepoPRGroup
local function build_group(workspace, repo, pullrequests)
	return {
		workspace = workspace,
		repo = repo,
		full_name = string.format("%s/%s", workspace, repo),
		pullrequests = pullrequests,
	}
end

---@param workspace string
---@param repo string
---@param opts { user: string, token: string, cache_ttl: number, force: boolean }
---@param on_done fun(groups: BitbucketRepoPRGroup[], err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
local function fetch_pullrequests(workspace, repo, opts, on_done)
	local key = cache_key(workspace, repo)
	if not opts.force then
		local cached = cache.get(key)
		if cached and cached.value then
			logger.loginfo("Bitbucket cache hit", { workspace = workspace, repo = repo })
			on_done({ cached.value }, nil)
			return nil
		end
	end

	logger.loginfo("Fetching pull requests", {
		workspace = workspace,
		repo = repo,
	})

	local url = build_pullrequests_open_url(workspace, repo)
	local headers = build_headers(opts.user, opts.token)

	return http.curl_request("GET", url, headers, nil, function(result, err)
		if err then
			logger.logerror("Bitbucket PR fetch failed", {
				workspace = workspace,
				repo = repo,
				error = err,
			})
			on_done({}, err)
			return
		end

		if type(result) ~= "table" then
			logger.logerror("Bitbucket PR fetch invalid response", {
				workspace = workspace,
				repo = repo,
			})
			on_done({}, "Bitbucket response is not a JSON object")
			return
		end

		if result.error then
			local message = "Bitbucket API error"
			if type(result.error) == "table" and result.error.message then
				message = tostring(result.error.message)
			elseif type(result.error) == "string" then
				message = result.error
			end
			logger.logerror("Bitbucket PR fetch API error", {
				workspace = workspace,
				repo = repo,
				error = message,
			})
			on_done({}, message)
			return
		end

		local raw_values = result.values or {}
		local normalized = normalizer.normalize_prs(raw_values, workspace, repo)
		local group = build_group(workspace, repo, normalized)

		cache.set(key, group, opts.cache_ttl)

		logger.loginfo("Fetch success", {
			workspace = workspace,
			repo = repo,
			pr_count = #normalized,
			cached = true,
		})

		on_done({ group }, nil)
	end)
end

---@param view_repos BitbucketRepoConfig[]
---@param opts { force_load: boolean }
---@param on_done fun(values: table[], err: string[]|nil)
---@return { cancel: fun() }|nil
function M.fetch_pullrequests(view_repos, opts, on_done)
	if view_repos == nil or #view_repos == 0 then
		on_done({}, nil)
		return nil
	end

	logger.loginfo("Bitbucket batch fetch start", {
		repo_count = #view_repos,
	})

	local ttl = ((config.options.bitbucket and config.options.bitbucket.cache_ttl) or 300)
	local user, token, auth_err = get_auth_from_config()
	if auth_err then
		logger.logerror("Bitbucket auth missing", { error = auth_err })
		vim.notify("Atlas Bitbucket: " .. auth_err, vim.log.levels.ERROR)
		on_done({}, auth_err)
		return nil
	end

	---TODO: Any nicer way to make to make multiple async calls and wait for all of them to finish? Maybe use plenary's async features?
	local pending = #view_repos
	local done = false
	local all_groups = {}
	local errors = {}
	local handles = {}

	local function cancel_all()
		done = true
		for _, handle in ipairs(handles) do
			if handle and handle.cancel then
				pcall(handle.cancel)
			end
		end
	end

	local function finish(groups, err)
		if done then
			return
		end

		if err then
			table.insert(errors, tostring(err))
		end

		for _, group in ipairs(groups or {}) do
			table.insert(all_groups, group)
		end

		pending = pending - 1
		if pending == 0 then
			done = true

			logger.loginfo("Bitbucket batch fetch completed", {
				repo_count = #view_repos,
				group_count = #all_groups,
				error_count = #errors,
			})
			if #errors > 0 then
				on_done(all_groups, errors)
			else
				on_done(all_groups, nil)
			end
		end
	end

	for _, repo in ipairs(view_repos) do
		local handle = fetch_pullrequests(
			repo.workspace,
			repo.repo,
			{ user = user, token = token, cache_ttl = ttl, force = opts.force_load },
			finish
		)
		if handle ~= nil then
			table.insert(handles, handle)
		end
	end

	return {
		cancel = cancel_all,
	}
end

---@param workspace string
---@param repo string
---@param pr_id string|number
---@param opts { force_load?: boolean }
---@param on_done fun(detail: BitbucketPRDetail|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.fetch_pullrequest_detail(workspace, repo, pr_id, opts, on_done)
	opts = opts or {}
	local ttl = ((config.options.bitbucket and config.options.bitbucket.cache_ttl) or 300)
	local detail_cache_key = string.format("bitbucket:mem:pr_detail:%s/%s/%s", workspace, repo, tostring(pr_id))
	if not opts.force_load then
		local cached = memory_cache.get(detail_cache_key)
		if cached and cached.value then
			on_done(cached.value, nil)
			return nil
		end
	end

	local user, token, auth_err = get_auth_from_config()
	if auth_err then
		on_done(nil, auth_err)
		return nil
	end

	local url = build_pullrequest_detail_url(workspace, repo, pr_id)
	local headers = build_headers(user, token)

	return http.curl_request("GET", url, headers, nil, function(result, err)
		if err then
			on_done(nil, err)
			return
		end

		if type(result) ~= "table" then
			on_done(nil, "Bitbucket response is not a JSON object")
			return
		end

		if result.error then
			local message = "Bitbucket API error"
			if type(result.error) == "table" and result.error.message then
				message = tostring(result.error.message)
			elseif type(result.error) == "string" then
				message = result.error
			end
			on_done(nil, message)
			return
		end

		local detail = normalizer.normalize_pr_detail(result, workspace, repo)
		memory_cache.set(detail_cache_key, detail, ttl)

		on_done(detail, nil)
	end)
end

---@param diffstat_url string
---@param opts { force_load?: boolean }
---@param on_done fun(diffstat: BitbucketPRDiffstat|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.fetch_pullrequest_diffstat(diffstat_url, opts, on_done)
	opts = opts or {}
	local ttl = ((config.options.bitbucket and config.options.bitbucket.cache_ttl) or 300)
	if type(diffstat_url) ~= "string" or diffstat_url == "" then
		on_done(nil, "Missing Bitbucket diffstat URL")
		return nil
	end

	local diffstat_cache_key = string.format("bitbucket:mem:pr_diffstat:%s", diffstat_url)
	if not opts.force_load then
		local cached = memory_cache.get(diffstat_cache_key)
		if cached and cached.value then
			on_done(cached.value, nil)
			return nil
		end
	end

	local user, token, auth_err = get_auth_from_config()
	if auth_err then
		on_done(nil, auth_err)
		return nil
	end

	local headers = build_headers(user, token)

	return http.curl_request("GET", diffstat_url, headers, nil, function(result, err)
		if err then
			on_done(nil, err)
			return
		end

		if type(result) ~= "table" then
			on_done(nil, "Bitbucket response is not a JSON object")
			return
		end

		if result.error then
			local message = "Bitbucket API error"
			if type(result.error) == "table" and result.error.message then
				message = tostring(result.error.message)
			elseif type(result.error) == "string" then
				message = result.error
			end
			on_done(nil, message)
			return
		end

		local diffstat = normalize_diffstat(result)
		memory_cache.set(diffstat_cache_key, diffstat, ttl)
		on_done(diffstat, nil)
	end)
end

---@param commits_url string
---@param opts { force_load?: boolean }
---@param on_done fun(commits: BitbucketPRCommits|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.fetch_pullrequest_commits(commits_url, opts, on_done)
	opts = opts or {}
	local ttl = ((config.options.bitbucket and config.options.bitbucket.cache_ttl) or 300)
	if type(commits_url) ~= "string" or commits_url == "" then
		on_done(nil, "Missing Bitbucket commits URL")
		return nil
	end

	local commits_cache_key = string.format("bitbucket:mem:pr_commits:%s", commits_url)
	if not opts.force_load then
		local cached = memory_cache.get(commits_cache_key)
		if cached and cached.value then
			on_done(cached.value, nil)
			return nil
		end
	end

	local user, token, auth_err = get_auth_from_config()
	if auth_err then
		on_done(nil, auth_err)
		return nil
	end

	local headers = build_headers(user, token)

	return http.curl_request("GET", commits_url, headers, nil, function(result, err)
		if err then
			on_done(nil, err)
			return
		end

		if type(result) ~= "table" then
			on_done(nil, "Bitbucket response is not a JSON object")
			return
		end

		if result.error then
			local message = "Bitbucket API error"
			if type(result.error) == "table" and result.error.message then
				message = tostring(result.error.message)
			elseif type(result.error) == "string" then
				message = result.error
			end
			on_done(nil, message)
			return
		end

		local commits = normalize_commits(result)
		memory_cache.set(commits_cache_key, commits, ttl)
		on_done(commits, nil)
	end)
end

---@param diff_url string
---@param opts { force_load?: boolean }
---@param on_done fun(diff: BitbucketPRDiff|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.fetch_pullrequest_diff(diff_url, opts, on_done)
	opts = opts or {}
	local ttl = ((config.options.bitbucket and config.options.bitbucket.cache_ttl) or 300)
	if type(diff_url) ~= "string" or diff_url == "" then
		on_done(nil, "Missing Bitbucket diff URL")
		return nil
	end

	local diff_cache_key = string.format("bitbucket:mem:pr_diff:%s", diff_url)
	if not opts.force_load then
		local cached = memory_cache.get(diff_cache_key)
		if cached and cached.value then
			on_done(cached.value, nil)
			return nil
		end
	end

	local user, token, auth_err = get_auth_from_config()
	if auth_err then
		on_done(nil, auth_err)
		return nil
	end

	local headers = build_headers(user, token)

	return curl_text_request(diff_url, headers, function(text, err)
		if err then
			on_done(nil, err)
			return
		end

		local diff = { text = text or "" }
		memory_cache.set(diff_cache_key, diff, ttl)
		on_done(diff, nil)
	end)
end

---@param activity_url string
---@param opts { force_load?: boolean }
---@param on_done fun(activity: BitbucketPRActivity|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.fetch_pullrequest_activity(activity_url, opts, on_done)
	opts = opts or {}
	local ttl = ((config.options.bitbucket and config.options.bitbucket.cache_ttl) or 300)
	if type(activity_url) ~= "string" or activity_url == "" then
		on_done(nil, "Missing Bitbucket activity URL")
		return nil
	end

	local activity_cache_key = string.format("bitbucket:mem:pr_activity:%s", activity_url)
	if not opts.force_load then
		local cached = memory_cache.get(activity_cache_key)
		if cached and cached.value then
			on_done(cached.value, nil)
			return nil
		end
	end

	local user, token, auth_err = get_auth_from_config()
	if auth_err then
		on_done(nil, auth_err)
		return nil
	end

	local headers = build_headers(user, token)

	return http.curl_request("GET", activity_url, headers, nil, function(result, err)
		if err then
			on_done(nil, err)
			return
		end

		if type(result) ~= "table" then
			on_done(nil, "Bitbucket response is not a JSON object")
			return
		end

		if result.error then
			local message = "Bitbucket API error"
			if type(result.error) == "table" and result.error.message then
				message = tostring(result.error.message)
			elseif type(result.error) == "string" then
				message = result.error
			end
			on_done(nil, message)
			return
		end

		local activity = normalizer.normalize_pr_activity(result)
		memory_cache.set(activity_cache_key, activity, ttl)
		on_done(activity, nil)
	end)
end

---@param comments_url string
---@param opts { force_load?: boolean }
---@param on_done fun(comments: BitbucketPRComments|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.fetch_pullrequest_comments(comments_url, opts, on_done)
	opts = opts or {}
	local ttl = ((config.options.bitbucket and config.options.bitbucket.cache_ttl) or 300)
	if type(comments_url) ~= "string" or comments_url == "" then
		on_done(nil, "Missing Bitbucket comments URL")
		return nil
	end

	local comments_cache_key = string.format("bitbucket:mem:pr_comments:%s", comments_url)
	if not opts.force_load then
		local cached = memory_cache.get(comments_cache_key)
		if cached and cached.value then
			on_done(cached.value, nil)
			return nil
		end
	end

	local user, token, auth_err = get_auth_from_config()
	if auth_err then
		on_done(nil, auth_err)
		return nil
	end

	local headers = build_headers(user, token)

	return http.curl_request("GET", comments_url, headers, nil, function(result, err)
		if err then
			on_done(nil, err)
			return
		end

		if type(result) ~= "table" then
			on_done(nil, "Bitbucket response is not a JSON object")
			return
		end

		if result.error then
			local message = "Bitbucket API error"
			if type(result.error) == "table" and result.error.message then
				message = tostring(result.error.message)
			elseif type(result.error) == "string" then
				message = result.error
			end
			on_done(nil, message)
			return
		end

		local comments = normalizer.normalize_pr_comments(result)
		memory_cache.set(comments_cache_key, comments, ttl)
		on_done(comments, nil)
	end)
end

---@param url string
---@param data table|nil
---@param on_done fun(result: table|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
local function post_to_url(url, data, on_done)
	logger.loginfo("Bitbucket POST start", {
		url = url,
		has_body = type(data) == "table",
	})

	local user, token, auth_err = get_auth_from_config()
	if auth_err then
		logger.logerror("Bitbucket POST auth missing", { url = url, error = auth_err })
		on_done(nil, auth_err)
		return nil
	end

	local headers = build_headers(user, token)
	local payload = nil
	if type(data) == "table" then
		payload = vim.json.encode(data)
	end

	return http.curl_request("POST", url, headers, payload, function(result, err)
		if err then
			local status = err:match("Status:%s*(%d+)")
			local raw_body = err:match("Raw:%s*([%s%S]*)")
			logger.logerror("Bitbucket POST failed", {
				url = url,
				status = status or "",
				body = raw_body or "",
				error = err,
			})
			on_done(nil, err)
			return
		end

		if type(result) ~= "table" then
			on_done(nil, "Bitbucket response is not a JSON object")
			return
		end

		local api_err = api_error_message(result)
		if api_err ~= nil then
			logger.logerror("Bitbucket POST API error", {
				url = url,
				status = tostring(result.__http_status or ""),
				error = api_err,
			})
			on_done(nil, api_err)
			return
		end

		logger.loginfo("Bitbucket POST success", {
			url = url,
			status = tostring(result.__http_status or ""),
		})

		on_done(result, nil)
	end)
end

---@param merge_url string
---@param opts { message?: string, close_source_branch?: boolean, merge_strategy?: string }|nil
---@param on_done fun(result: table|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.merge_pullrequest(merge_url, opts, on_done)
	opts = opts or {}
	local payload = {
		close_source_branch = opts.close_source_branch == true,
		merge_strategy = tostring(opts.merge_strategy or "merge_commit"), --TODO: Refactor to config
	}
	if type(opts.message) == "string" and opts.message ~= "" then
		payload.message = opts.message
	end
	return post_to_url(merge_url, payload, on_done)
end

---@param approve_url string
---@param on_done fun(result: table|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.approve_pullrequest(approve_url, on_done)
	return post_to_url(approve_url, nil, on_done)
end

---@param request_changes_url string
---@param on_done fun(result: table|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.request_changes_pullrequest(request_changes_url, on_done)
	return post_to_url(request_changes_url, nil, on_done)
end

---@param on_done fun(workspaces: BitbucketWorkspace[]|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.fetch_user_workspaces(on_done)
	local ttl = ((config.options.bitbucket and config.options.bitbucket.cache_ttl) or 300)
	local workspace_cache_key = "bitbucket:mem:user_workspaces"
	local workspace_cached = memory_cache.get(workspace_cache_key)
	if workspace_cached and workspace_cached.value then
		logger.loginfo("Bitbucket workspace memory cache hit", {
			workspace_count = #(workspace_cached.value or {}),
		})
		on_done(workspace_cached.value, nil)
		return nil
	end

	local user, token, auth_err = get_auth_from_config()
	if auth_err then
		on_done(nil, auth_err)
		return nil
	end

	local url = API_BASE .. ENDPOINTS.user_workspaces
	local headers = build_headers(user, token)

	logger.loginfo("Bitbucket workspace fetch start", { url = url })
	return http.curl_request("GET", url, headers, nil, function(result, err)
		if err then
			logger.logerror("Bitbucket workspace fetch failed", { url = url, error = err })
			on_done(nil, err)
			return
		end

		if type(result) ~= "table" then
			logger.logerror("Bitbucket workspace fetch invalid response", { url = url })
			on_done(nil, "Bitbucket response is not a JSON object")
			return
		end

		if result.error then
			local message = "Bitbucket API error"
			if type(result.error) == "table" and result.error.message then
				message = tostring(result.error.message)
			elseif type(result.error) == "string" then
				message = result.error
			end
			logger.logerror("Bitbucket workspace fetch API error", {
				url = url,
				error = message,
			})
			on_done(nil, message)
			return
		end

		local workspaces = {}
		for _, item in ipairs((result.values or {})) do
			local workspace = (type(item.workspace) == "table") and item.workspace or {}
			table.insert(workspaces, {
				slug = tostring(workspace.slug or ""),
				uuid = tostring(workspace.uuid or ""),
				administrator = item.administrator == true,
			})
		end

		logger.loginfo("Bitbucket workspace fetch success", {
			url = url,
			workspace_count = #workspaces,
		})
		memory_cache.set(workspace_cache_key, workspaces, ttl)

		on_done(workspaces, nil)
	end)
end

---@param on_done fun(user: BitbucketCurrentUser|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.fetch_current_user(on_done)
	local user, token, auth_err = get_auth_from_config()
	if auth_err then
		on_done(nil, auth_err)
		return nil
	end

	local cachekey = string.format("bitbucket:user_profile:%s", user)
	local cached = cache.get(cachekey)
	if cached and cached.value then
		logger.loginfo("Bitbucket current user cache hit", { user = user })
		on_done(cached.value, nil)
		return nil
	end

	local url = API_BASE .. ENDPOINTS.user_profile
	local headers = build_headers(user, token)

	logger.loginfo("Bitbucket current user fetch start", { url = url })
	return http.curl_request("GET", url, headers, nil, function(result, err)
		if err then
			logger.logerror("Bitbucket current user fetch failed", { url = url, error = err })
			on_done(nil, err)
			return
		end

		if type(result) ~= "table" then
			logger.logerror("Bitbucket current user invalid response", { url = url })
			on_done(nil, "Bitbucket response is not a JSON object")
			return
		end

		if result.error then
			local message = "Bitbucket API error"
			if type(result.error) == "table" and result.error.message then
				message = tostring(result.error.message)
			elseif type(result.error) == "string" then
				message = result.error
			end
			logger.logerror("Bitbucket current user API error", {
				url = url,
				error = message,
			})
			on_done(nil, message)
			return
		end

		local current_user = {
			type = tostring(result.type or ""),
			created_on = tostring(result.created_on or ""),
			display_name = tostring(result.display_name or ""),
			nickname = tostring(result.nickname or ""),
			username = tostring(result.username or ""),
			uuid = tostring(result.uuid or ""),
		}

		logger.loginfo("Bitbucket current user fetch success", {
			url = url,
			display_name = current_user.display_name,
		})
		cache.set(cachekey, current_user, 86400)

		on_done(current_user, nil)
	end)
end

---@param workspace string
---@param search string
---@param on_done fun(repositories: BitbucketRepository[]|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.fetch_workspace_repositories(workspace, search, on_done)
	if type(workspace) ~= "string" or workspace == "" then
		on_done(nil, "Missing workspace slug")
		return nil
	end
	local term = tostring(search or "")

	local user, token, auth_err = get_auth_from_config()
	if auth_err then
		logger.logerror("Bitbucket repo fetch auth missing", {
			workspace = workspace,
			error = auth_err,
		})
		on_done(nil, auth_err)
		return nil
	end

	local encoded_workspace = workspace
	local query_prefix = ""
	if term ~= "" then
		local escaped_term = term:gsub('"', '\\"')
		local q_expression = string.format('name~"%s"', escaped_term)
		local encoded_q = q_expression:gsub('"', "%%22"):gsub(" ", "%%20")
		query_prefix = string.format("q=%s&", encoded_q)
	end
	local url = API_BASE .. string.format(ENDPOINTS.repositories, encoded_workspace, query_prefix)
	logger.loginfo("Bitbucket repo fetch start", {
		workspace = workspace,
		search = term,
		url = url,
	})

	local headers = build_headers(user, token)
	return http.curl_request("GET", url, headers, nil, function(result, err)
		if err then
			logger.logerror("Bitbucket repo fetch failed", {
				workspace = workspace,
				search = term,
				error = err,
			})
			on_done(nil, err)
			return
		end

		if type(result) ~= "table" then
			logger.logerror("Bitbucket repo fetch invalid response", {
				workspace = workspace,
				search = term,
			})
			on_done(nil, "Bitbucket response is not a JSON object")
			return
		end

		if result.error then
			local message = "Bitbucket API error"
			if type(result.error) == "table" and result.error.message then
				message = tostring(result.error.message)
			elseif type(result.error) == "string" then
				message = result.error
			end
			logger.logerror("Bitbucket repo fetch API error", {
				workspace = workspace,
				search = term,
				error = message,
			})
			on_done(nil, message)
			return
		end

		local repositories = {}
		for _, repo in ipairs((result.values or {})) do
			local full_name = tostring(repo.full_name or "")
			local repo_workspace, repo_slug = full_name:match("^([^/]+)/(.+)$")
			table.insert(repositories, {
				uuid = tostring(repo.uuid or ""),
				name = tostring(repo.name or ""),
				full_name = full_name,
				slug = tostring(repo_slug or repo.slug or ""),
				workspace = tostring(repo_workspace or workspace),
				is_private = repo.is_private == true,
				updated_on = tostring(repo.updated_on or ""),
			})
		end

		logger.loginfo("Bitbucket repo fetch success", {
			workspace = workspace,
			search = term,
			repo_count = #repositories,
		})

		on_done(repositories, nil)
	end)
end

return M
