local M = {}

local service = require("atlas.bitbucketv2.api.service")
local normalizer = require("atlas.bitbucketv2.api.normalizer")
local cache = require("atlas.core.cache")
local memory_cache = require("atlas.core.memory_cache")
local logger = require("atlas.core.logger")
local http = require("atlas.core.http")
local state = require("atlas.bitbucketv2.state")

---@param workspace string
---@param repo string
---@return string
local function cache_key(workspace, repo)
	return string.format("bitbucket:prs:%s/%s", workspace, repo)
end

---@param workspace string
---@param repo string
---@param readme string|nil
---@param pullrequests BitbucketPR[]
---@return BitbucketRepoPRGroup
local function build_group(workspace, repo, readme, pullrequests)
	return {
		workspace = workspace,
		repo = repo,
		full_name = string.format("%s/%s", workspace, repo),
		readme = (type(readme) == "string" and readme ~= "") and readme or "README.md",
		pullrequests = pullrequests,
	}
end

---@param workspace string
---@param repo string
---@param opts { user: string, token: string, cache_ttl: number, force: boolean, readme?: string|nil }
---@param on_done fun(groups: BitbucketRepoPRGroup[], err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
local function fetch_pullrequests_single(workspace, repo, opts, on_done)
	local key = cache_key(workspace, repo)
	if not opts.force then
		local cached = cache.get(key)
		if cached and cached.value then
			logger.loginfo("Bitbucket cache hit", { workspace = workspace, repo = repo })
			if cached.value.readme == nil or cached.value.readme == "" then
				cached.value.readme = (type(opts.readme) == "string" and opts.readme ~= "") and opts.readme
					or "README.md"
			end
			on_done({ cached.value }, nil)
			return nil
		end
	end

	logger.loginfo("Fetching pull requests", {
		workspace = workspace,
		repo = repo,
	})

	local endpoint = string.format("/repositories/%s/%s/pullrequests?state=%s&pagelen=50", workspace, repo, state.pr_state)
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

		local raw_values = result.values or {}
		local normalized = normalizer.normalize_prs(raw_values, workspace, repo)
		local group = build_group(workspace, repo, opts.readme, normalized)

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
---@param on_done fun(values: BitbucketRepoPRGroup[], err: string[]|nil)
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
		local handle = fetch_pullrequests_single(
			repo.workspace,
			repo.repo,
			{ user = user, token = token, cache_ttl = ttl, force = opts.force_load, readme = repo.readme },
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
---@param on_done fun(pr: BitbucketPR|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.fetch_pullrequest(workspace, repo, pr_id, on_done)
	local endpoint = string.format("/repositories/%s/%s/pullrequests/%s", workspace, repo, tostring(pr_id))
	return service.request("GET", endpoint, nil, nil, function(result, err)
		if err then
			on_done(nil, err)
			return
		end

		local pr = normalizer.normalize_pr(result, workspace, repo)
		on_done(pr, nil)
	end)
end

---@param workspace string
---@param repo string
---@param pr_id string|number
---@param opts { force_load?: boolean }
---@param on_done fun(detail: BitbucketPRDetail|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.fetch_detail(workspace, repo, pr_id, opts, on_done)
	opts = opts or {}
	local ttl = service.cache_ttl()
	local detail_cache_key = string.format("bitbucket:mem:pr_detail:%s/%s/%s", workspace, repo, tostring(pr_id))
	if not opts.force_load then
		local cached = memory_cache.get(detail_cache_key)
		if cached and cached.value then
			on_done(cached.value, nil)
			return nil
		end
	end

	local endpoint = string.format("/repositories/%s/%s/pullrequests/%s", workspace, repo, tostring(pr_id))
	return service.request("GET", endpoint, nil, nil, function(result, err)
		if err then
			on_done(nil, err)
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
function M.fetch_diffstat(diffstat_url, opts, on_done)
	opts = opts or {}
	local ttl = service.cache_ttl()
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

	return service.request("GET", diffstat_url, nil, nil, function(result, err)
		if err then
			on_done(nil, err)
			return
		end

		local diffstat = normalizer.normalize_pr_diffstat(result)
		memory_cache.set(diffstat_cache_key, diffstat, ttl)
		on_done(diffstat, nil)
	end)
end

---@param commits_url string
---@param opts { force_load?: boolean }
---@param on_done fun(commits: BitbucketPRCommits|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.fetch_commits(commits_url, opts, on_done)
	opts = opts or {}
	local ttl = service.cache_ttl()
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

	return service.request("GET", commits_url, nil, nil, function(result, err)
		if err then
			on_done(nil, err)
			return
		end

		local commits = normalizer.normalize_pr_commits(result)
		memory_cache.set(commits_cache_key, commits, ttl)
		on_done(commits, nil)
	end)
end

---@param diff_url string
---@param opts { force_load?: boolean }
---@param on_done fun(diff: BitbucketPRDiff|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.fetch_diff(diff_url, opts, on_done)
	opts = opts or {}
	local ttl = service.cache_ttl()
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

	return service.request_text("GET", diff_url, nil, nil, function(text, err)
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
function M.fetch_activity(activity_url, opts, on_done)
	opts = opts or {}
	local ttl = service.cache_ttl()
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

	return service.request("GET", activity_url, nil, nil, function(result, err)
		if err then
			on_done(nil, err)
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
function M.fetch_comments(comments_url, opts, on_done)
	opts = opts or {}
	local ttl = service.cache_ttl()
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

	return service.request("GET", comments_url, nil, nil, function(result, err)
		if err then
			on_done(nil, err)
			return
		end

		local comments = normalizer.normalize_pr_comments(result)
		memory_cache.set(comments_cache_key, comments, ttl)
		on_done(comments, nil)
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
