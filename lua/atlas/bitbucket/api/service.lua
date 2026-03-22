local M = {}
local config = require("atlas.config")
local normalizer = require("atlas.bitbucket.api.normalizer")

local API_BASE = "https://api.bitbucket.org/2.0"

local ENDPOINTS = {
	pullrequests_open = "/repositories/%s/%s/pullrequests?state=OPEN&pagelen=100",
}

--- TODO: Just for testing
local function load_mock_json()
	local this_file = debug.getinfo(1, "S").source:sub(2)
	local this_dir = vim.fn.fnamemodify(this_file, ":p:h")
	local path = this_dir .. "/mock_pullrequests.json"
	local lines = vim.fn.readfile(path)
	local text = table.concat(lines, "\n")
	local decoded = vim.json.decode(text)
	return (decoded and decoded.values) or {}
end
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

local function get_auth_from_config()
	local bb = (config.options and config.options.bitbucket) or {}
	local user = bb.user
	local token = bb.token

	if not user or user == "" or not token or token == "" then
		return nil, nil, "Missing Bitbucket credentials in config (bitbucket.user / bitbucket.token)"
	end

	return user, token, nil
end

---@param on_done fun(groups: BitbucketRepoPRGroup[], err: string|nil)
local function fetch_pullrequests(workspace, repo, opts, on_done)
	local url = build_pullrequests_open_url(workspace, repo)
	local headers = build_headers(opts.user, opts.token)
	local pullrequests = load_mock_json()

	--- TODO: Add real http request here, for now just load from file
	vim.defer_fn(function()
		on_done({
			{
				workspace = workspace,
				repo = repo,
				full_name = string.format("%s/%s", workspace, repo),
				pullrequests = normalizer.normalize_prs(pullrequests),
			},
		}, nil)
	end, 2000)
end

---@param view_repos BitbucketRepoConfig[]
---@param on_done fun(values: table[], err: string|nil)
function M.fetch_pullrequests(view_repos, on_done)
	if view_repos == nil or #view_repos == 0 then
		on_done({}, nil)
		return
	end

	local user, token, auth_err = get_auth_from_config()
	if auth_err then
		on_done({}, auth_err)
		return
	end

	---TODO: Any nicer way to make to make multiple async calls and wait for all of them to finish? Maybe use plenary's async features?
	local pending = #view_repos
	local done = false
	local all_groups = {}
	local errors = {}

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
			if #errors > 0 then
				on_done(all_groups, table.concat(errors, " | "))
			else
				on_done(all_groups, nil)
			end
		end
	end

	for _, repo in ipairs(view_repos) do
		fetch_pullrequests(repo.workspace, repo.repo, { user = user, token = token }, finish)
	end
end

return M
