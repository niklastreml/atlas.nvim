local M = {}

local cli = require("atlas.pulls.providers.github.api.cli")
local normalizer = require("atlas.pulls.providers.github.api.normalizer")
local logger = require("atlas.core.logger")

local DETAIL_FIELDS = {
	"number",
	"title",
	"author",
	"headRefName",
	"baseRefName",
	"headRefOid",
	"baseRefOid",
	"state",
	"isDraft",
	"createdAt",
	"updatedAt",
	"url",
	"body",
	"reviewDecision",
	"additions",
	"deletions",
	"changedFiles",
	"comments",
}

local SEARCH_GQL = [[
query($search: String!, $limit: Int!) {
  search(query: $search, type: ISSUE, first: $limit) {
    nodes {
      ... on PullRequest {
        number title state isDraft
        createdAt updatedAt url
        additions deletions changedFiles
        latestOpinionatedReviews(last: 10) { nodes { state } }
        author { login ... on User { name } }
        headRefName baseRefName
        comments { totalCount }
        repository { name nameWithOwner }
        commits(last: 1) {
          nodes { commit { statusCheckRollup { state } } }
        }
      }
    }
  }
}
]]

---@param search string
---@param on_done fun(groups: PullsGroup[], err: string[]|nil)
---@param opts { force_load?: boolean, limit?: number }|nil
---@return { cancel: fun() }|nil
function M.search_prs(search, on_done, opts)
	opts = opts or {}
	local limit = math.max(1, tonumber(opts.limit) or 50)
	local cache_key = string.format("github:search:%s:limit:%d", search, limit)

	if not opts.force_load then
		local cached, ok = cli.get_cache(cache_key)
		if ok then
			on_done(cached, nil)
			return nil
		end
	end

	logger.loginfo("GitHub GraphQL search PRs", { search = search, limit = limit })

	return cli.gh({
		"api",
		"graphql",
		"-f",
		"query=" .. vim.trim(SEARCH_GQL),
		"-f",
		"search=" .. search,
		"-F",
		"limit=" .. tostring(limit),
	}, function(result, err)
		if err then
			on_done({}, { err })
			return
		end

		local nodes = type(result) == "table"
				and type(result.data) == "table"
				and type(result.data.search) == "table"
				and result.data.search.nodes
			or nil

		if type(nodes) ~= "table" then
			on_done({}, nil)
			return
		end

		local prs = normalizer.normalize_graphql_search_results(nodes)
		local groups = normalizer.group_by_repo(prs)

		cli.set_cache(cache_key, groups)
		logger.loginfo("GitHub GraphQL search complete", { count = #prs, groups = #groups })
		on_done(groups, nil)
	end)
end

---@param owner string
---@param repo string
---@param number number|string
---@param on_done fun(pr: PullRequest|nil, err: string|nil)
---@param opts { force_load?: boolean }|nil
---@return { job_id: integer, cancel: fun() }|nil
function M.get_pr(owner, repo, number, on_done, opts)
	opts = opts or {}
	local repo_slug = string.format("%s/%s", owner, repo)
	local cache_key = string.format("github:pr:%s:%s", repo_slug, tostring(number))

	if not opts.force_load then
		local cached, ok = cli.get_cache(cache_key)
		if ok then
			on_done(cached, nil)
			return nil
		end
	end

	logger.loginfo("GitHub fetch PR", { repo = repo_slug, number = number })

	local args = {
		"pr",
		"view",
		tostring(number),
		"--repo",
		repo_slug,
		"--json",
		table.concat(DETAIL_FIELDS, ","),
	}

	return cli.gh(args, function(result, err)
		if err or not result or type(result) ~= "table" then
			on_done(nil, err or "Failed to fetch PR")
			return
		end

		if not result.repository then
			result.repository = { name = repo, nameWithOwner = repo_slug }
		end

		local pr = normalizer.normalize_pr(result)
		cli.set_cache(cache_key, pr)
		on_done(pr, nil)
	end)
end

return M
