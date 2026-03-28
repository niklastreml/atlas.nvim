local M = {}
local config = require("atlas.config")
local normalizer = require("atlas.bitbucket.api.normalizer")
local logger = require("atlas.core.logger")
local cache = require("atlas.core.cache")
local http = require("atlas.core.http")
local request_manager = require("atlas.core.request_manager")
local footer = require("atlas.ui.components.footer")
local icons = require("atlas.ui.icons")

local API_BASE = "https://api.bitbucket.org/2.0"

local ENDPOINTS = {
	pullrequests_open = "/repositories/%s/%s/pullrequests?state=OPEN&pagelen=50",
}

local function build_pullrequests_open_url(workspace, repo)
	return API_BASE .. string.format(ENDPOINTS.pullrequests_open, workspace, repo)
end

local function build_headers(user, token)
	local auth = vim.base64.encode(string.format("%s:%s", user or "", token or ""))
	return {
		Authorization = "Basic " .. auth,
		["Content-Type"] = "application/json",
		Accept = "application/json",
	}
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
			on_done({}, err)
			return
		end

		if type(result) ~= "table" then
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
			on_done({}, message)
			return
		end

		local raw_values = result.values or {}
		local normalized = normalizer.normalize_prs(raw_values)
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
---@param opts { force_load: boolean, request_scope: string }
---@param on_done fun(values: table[], err: string|nil)
function M.fetch_pullrequests(view_repos, opts, on_done)
	if view_repos == nil or #view_repos == 0 then
		on_done({}, nil)
		return
	end

	logger.loginfo("Bitbucket batch fetch start", {
		repo_count = #view_repos,
	})

	local request_scope = opts.request_scope
	local request_id = request_manager.begin(request_scope)

	local ttl = ((config.options.bitbucket and config.options.bitbucket.cache_ttl) or 300)
	local user, token, auth_err = get_auth_from_config()
	if auth_err then
		if request_manager.is_latest(request_scope, request_id) then
			logger.logerror("Bitbucket auth missing", { error = auth_err })
			vim.notify("Atlas Bitbucket: " .. auth_err, vim.log.levels.ERROR)
			on_done({}, auth_err)
		end
		request_manager.finish(request_scope, request_id)
		return
	end

	---TODO: Any nicer way to make to make multiple async calls and wait for all of them to finish? Maybe use plenary's async features?
	local pending = #view_repos
	local done = false
	local all_groups = {}
	local errors = {}
	local handles = {}

	request_manager.attach_cancel(request_scope, request_id, function()
		for _, handle in ipairs(handles) do
			if handle and handle.cancel then
				pcall(handle.cancel)
			end
		end
	end)

	local function finish(groups, err)
		if done then
			return
		end

		if not request_manager.is_latest(request_scope, request_id) then
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
				on_done(all_groups, table.concat(errors, " | "))
			else
				local pr_count = 0
				for _, group in ipairs(all_groups) do
					pr_count = pr_count + #(group.pullrequests or {})
				end
				footer.notify(
					"success",
					string.format("%s Successful fetch %d pull request(s)", icons.entity("success"), pr_count),
					2800
				)
				on_done(all_groups, nil)
			end

			request_manager.finish(request_scope, request_id)
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
end

return M
