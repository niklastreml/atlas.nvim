local M = {}

local service = require("atlas.bitbucket.api.service")
local pr_normalizer = require("atlas.bitbucket.api.pr_normalizer")
local cache = require("atlas.core.cache")
local logger = require("atlas.core.logger")
local http = require("atlas.core.http")
local state = require("atlas.bitbucket.state")

---@param workspace string
---@param repo string
---@return string
local function cache_key(workspace, repo)
	return string.format("bitbucket:prs:%s/%s", workspace, repo)
end

---@param workspace string
---@param repo string
---@param opts { user: string, token: string, cache_ttl: number, force: boolean, pagelen: number|nil }
---@param on_done fun(prs: BitbucketPR[], err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
local function fetch_pullrequests_single(workspace, repo, opts, on_done)
	local key = cache_key(workspace, repo)
	if not opts.force then
		local cached = cache.get(key)
		if cached and cached.value then
			logger.loginfo("Bitbucket cache hit", { workspace = workspace, repo = repo })
			on_done(cached.value, nil)
			return nil
		end
	end

	logger.loginfo("Fetching pull requests", {
		workspace = workspace,
		repo = repo,
	})

	local endpoint = string.format(
		"/repositories/%s/%s/pullrequests?state=%s&pagelen=%d",
		workspace,
		repo,
		state.pr_state,
		tonumber(opts.pagelen) or 50
	)
	local user, token, _ = service.get_auth()
	local headers = service.build_headers(user, token)

	return http.curl_request("GET", service.url(endpoint), headers, nil, function(result, err)
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

		local api_err = service.api_error_message(result)
		if api_err then
			logger.logerror("Bitbucket PR fetch API error", {
				workspace = workspace,
				repo = repo,
				error = api_err,
			})
			on_done({}, api_err)
			return
		end

		local normalized = pr_normalizer.pullrequests(result, workspace, repo)
		cache.set(key, normalized, opts.cache_ttl)
		logger.loginfo("Fetch success", {
			workspace = workspace,
			repo = repo,
			pr_count = #normalized,
			cached = true,
		})

		on_done(normalized, nil)
	end)
end

---@param view_repos BitbucketRepoRef[]
---@param opts { force_load: boolean, pagelen: number|nil }
---@param on_done fun(values: BitbucketPR[], err: string[]|nil)
---@return { cancel: fun() }|nil
function M.fetch_pullrequests(view_repos, opts, on_done)
	if view_repos == nil or #view_repos == 0 then
		on_done({}, nil)
		return nil
	end

	logger.loginfo("Bitbucket batch fetch start", {
		repo_count = #view_repos,
	})

	local ttl = service.cache_ttl()
	local user, token, auth_err = service.get_auth()
	if auth_err then
		logger.logerror("Bitbucket auth missing", { error = auth_err })
		vim.notify("Atlas Bitbucket: " .. auth_err, vim.log.levels.ERROR)
		on_done({}, { tostring(auth_err) })
		return nil
	end

	local pending = #view_repos
	local done = false
	local all_prs = {}
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

	local function finish(prs, err)
		if done then
			return
		end

		if err then
			table.insert(errors, tostring(err))
		end

		for _, pr in ipairs(prs or {}) do
			table.insert(all_prs, pr)
		end

		pending = pending - 1
		if pending == 0 then
			done = true

			logger.loginfo("Bitbucket batch fetch completed", {
				repo_count = #view_repos,
				pr_count = #all_prs,
				error_count = #errors,
			})
			if #errors > 0 then
				on_done(all_prs, errors)
			else
				on_done(all_prs, nil)
			end
		end
	end

	for _, repo in ipairs(view_repos) do
		local handle = fetch_pullrequests_single(
			repo.workspace,
			repo.repo,
			{ user = user, token = token, cache_ttl = ttl, force = opts.force_load, pagelen = opts.pagelen },
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
---@param opts? { force_load?: boolean }
---@param on_done fun(detail: BitbucketPRDetail|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.fetch_pullrequest(workspace, repo, pr_id, opts, on_done)
	opts = opts or {}

	local key = string.format("bitbucket:pr:detail:%s/%s/%s", workspace, repo, tostring(pr_id))
	if opts.force_load ~= true then
		local cached, ok = service.get_cache(key)
		if ok then
			on_done(cached, nil)
			return nil
		end
	end

	local endpoint = string.format("/repositories/%s/%s/pullrequests/%s", workspace, repo, tostring(pr_id))
	return service.request("GET", endpoint, nil, nil, function(result, err)
		if err then
			on_done(nil, err)
			return
		end

		local detail = pr_normalizer.pr_detail(result, workspace, repo)
		if not detail then
			on_done(nil, "Invalid pull request detail response")
			return
		end
		service.set_cache(key, detail, service.cache_ttl())
		on_done(detail, nil)
	end)
end

---@param diffstat_url string
---@param opts? { force_load?: boolean }
---@param on_done fun(diffstat: BitbucketPRDiffstat|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.fetch_diffstat(diffstat_url, opts, on_done)
	opts = opts or {}

	if type(diffstat_url) ~= "string" or diffstat_url == "" then
		on_done(nil, "Missing Bitbucket diffstat URL")
		return nil
	end

	local key = "bitbucket:pr:diffstat:" .. diffstat_url
	if opts.force_load ~= true then
		local cached, ok = service.get_cache(key)
		if ok then
			on_done(cached, nil)
			return nil
		end
	end

	return service.request("GET", diffstat_url, nil, nil, function(result, err)
		if err then
			on_done(nil, err)
			return
		end

		local diffstat = pr_normalizer.pr_diffstat(result)
		service.set_cache(key, diffstat, service.cache_ttl())
		on_done(diffstat, nil)
	end)
end

---@param diff_url string
---@param opts? { force_load?: boolean }
---@param on_done fun(diff: string|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.fetch_diff(diff_url, opts, on_done)
	opts = opts or {}

	if type(diff_url) ~= "string" or diff_url == "" then
		on_done(nil, "Missing Bitbucket diff URL")
		return nil
	end

	local key = "bitbucket:pr:diff:" .. diff_url
	if opts.force_load ~= true then
		local cached, ok = service.get_cache(key)
		if ok then
			on_done(cached, nil)
			return nil
		end
	end

	return service.request_text("GET", diff_url, nil, nil, function(text, err)
		if err then
			on_done(nil, err)
			return
		end

		local diff = text or ""
		service.set_cache(key, diff, service.cache_ttl())
		on_done(diff, nil)
	end)
end

---@param commits_url string
---@param opts? { force_load?: boolean, pagelen?: number }
---@param on_done fun(commits: BitbucketPRCommits|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.fetch_commits(commits_url, opts, on_done)
	opts = opts or {}

	if type(commits_url) ~= "string" or commits_url == "" then
		on_done(nil, "Missing Bitbucket commits URL")
		return nil
	end

	local sep = commits_url:find("?") and "&" or "?"
	local url = string.format("%s%spagelen=%d", commits_url, sep, tonumber(opts.pagelen) or 50)
	local key = "bitbucket:pr:commits:" .. url
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

		local commits = pr_normalizer.pr_commits(result)
		service.set_cache(key, commits, service.cache_ttl())
		on_done(commits, nil)
	end)
end

---@param activity_url string
---@param opts? { force_load?: boolean, pagelen?: number }
---@param on_done fun(activity: BitbucketPRActivity|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.fetch_activity(activity_url, opts, on_done)
	opts = opts or {}

	if type(activity_url) ~= "string" or activity_url == "" then
		on_done(nil, "Missing Bitbucket activity URL")
		return nil
	end

	local sep = activity_url:find("?") and "&" or "?"
	local url = string.format("%s%spagelen=%d", activity_url, sep, tonumber(opts.pagelen) or 50)
	local key = "bitbucket:pr:activity:" .. url
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

		local activity = pr_normalizer.pr_activity(result)
		service.set_cache(key, activity, service.cache_ttl())
		on_done(activity, nil)
	end)
end

---@param statuses_url string
---@param opts? { force_load?: boolean, pagelen?: number }
---@param on_done fun(statuses: BitbucketPRStatuses|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.fetch_statuses(statuses_url, opts, on_done)
	opts = opts or {}

	if type(statuses_url) ~= "string" or statuses_url == "" then
		on_done(nil, "Missing Bitbucket statuses URL")
		return nil
	end

	local sep = statuses_url:find("?") and "&" or "?"
	local url = string.format("%s%spagelen=%d", statuses_url, sep, tonumber(opts.pagelen) or 30)
	local key = "bitbucket:pr:statuses:" .. url
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

		local statuses = pr_normalizer.pr_statuses(result)
		service.set_cache(key, statuses, service.cache_ttl())
		on_done(statuses, nil)
	end)
end

---@param statuses_url string
---@param opts? { force_load?: boolean, pagelen?: number }
---@param on_done fun(statuses: BitbucketPRStatuses|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.fetch_commit_statuses(statuses_url, opts, on_done)
	opts = opts or {}

	if type(statuses_url) ~= "string" or statuses_url == "" then
		on_done(nil, "Missing Bitbucket commit statuses URL")
		return nil
	end

	local sep = statuses_url:find("?") and "&" or "?"
	local url = string.format("%s%spagelen=%d", statuses_url, sep, tonumber(opts.pagelen) or 30)
	local key = "bitbucket:commit:statuses:" .. url
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

		local statuses = pr_normalizer.pr_statuses(result)
		service.set_cache(key, statuses, service.cache_ttl())
		on_done(statuses, nil)
	end)
end

---@param merge_url string
---@param opts { message?: string, close_source_branch?: boolean, merge_strategy?: string }|nil
---@param on_done fun(result: table|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.merge(merge_url, opts, on_done)
	opts = opts or {}
	local payload = {
		close_source_branch = opts.close_source_branch == true,
		merge_strategy = tostring(opts.merge_strategy or "merge_commit"),
	}
	if type(opts.message) == "string" and opts.message ~= "" then
		payload.message = opts.message
	end

	local body = vim.json.encode(payload)
	return service.request("POST", merge_url, nil, body, on_done)
end

---@param approve_url string
---@param on_done fun(result: table|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.approve(approve_url, on_done)
	return service.request("POST", approve_url, nil, nil, on_done)
end

---@param request_changes_url string
---@param on_done fun(result: table|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.request_changes(request_changes_url, on_done)
	return service.request("POST", request_changes_url, nil, nil, on_done)
end

return M
