local icons = require("atlas.ui.shared.icons")
local config = require("atlas.config")

---@class BitbucketProvider : PullsProvider
local M = {
	id = "bitbucket",
	name = "Bitbucket",
	icon = icons.pulls_provider("bitbucket", "provider"),
	hl_group = "AtlasBitbucketTheme",
	panel = require("atlas.pulls.providers.bitbucket.ui.panel"),
}

function M.setup()
	require("atlas.pulls.providers.bitbucket.highlights").setup()
end

---@return AtlasBitbucketConfig|nil
local function bb_config()
	return config.options
			and config.options.pulls
			and config.options.pulls.providers
			and config.options.pulls.providers.bitbucket
		or nil
end

---@param on_done fun(user: PullsUser|nil, err: string|nil)
function M.fetch_user(on_done)
	local users_api = require("atlas.pulls.providers.bitbucket.api.users")
	users_api.fetch_current_user(on_done)
end

---@param view AtlasPullsViewConfig
---@param opts PullsFetchOpts
---@param on_done fun(groups: PullsGroup[], err: string[]|nil)
---@return { cancel: fun() }|nil
function M.fetch_pullrequests(view, opts, on_done)
	local pr_api = require("atlas.pulls.providers.bitbucket.api.pullrequests")
	---@cast view AtlasBitbucketViewConfig

	return pr_api.fetch_pullrequests(view.repos or {}, {
		force_load = opts.force_load == true,
		pagelen = opts.pagelen,
	}, on_done)
end

---@param pr PullRequest
---@param opts PullsFetchOpts
---@param on_done fun(pr: PullRequest|nil, err: string|nil)
---@return { cancel: fun() }|nil
function M.fetch_pullrequest(pr, opts, on_done)
	local pr_api = require("atlas.pulls.providers.bitbucket.api.pullrequests")
	local workspace = tostring(pr.workspace or "")
	local repo = tostring(pr.repo or "")

	if workspace == "" or repo == "" then
		on_done(nil, "PR missing workspace/repo info")
		return nil
	end

	return pr_api.fetch_pullrequest(workspace, repo, pr.id, {
		force_load = opts.force_load == true,
	}, on_done)
end

---@return AtlasBitbucketViewConfig[]
function M.views()
	local cfg = bb_config()
	local view_configs = cfg and cfg.views or {}
	---@type AtlasBitbucketViewConfig[]
	local out = {}

	for _, v in ipairs(view_configs) do
		table.insert(out, {
			name = v.name,
			key = v.key,

			layout = v.layout,
			repos = v.repos,
			filter = v.filter,
		})
	end

	if #out == 0 then
		table.insert(out, {
			name = "Pull Requests",
			key = "1",

			layout = "compact",
			repos = {},
		})
	end

	return out
end

---@param pr PullRequest
---@param on_done fun(reviewers: PullsReviewer[]|nil, err: string|nil)
---@return { cancel: fun() }|nil
function M.fetch_reviewers(pr, on_done)
	local pr_api = require("atlas.pulls.providers.bitbucket.api.pullrequests")
	return pr_api.fetch_reviewers(pr, on_done)
end

---@param pr PullRequest
---@param on_done fun(builds: PullsBuild[]|nil, err: string|nil)
---@return { cancel: fun() }|nil
function M.fetch_builds(pr, on_done)
	local pr_api = require("atlas.pulls.providers.bitbucket.api.pullrequests")
	return pr_api.fetch_builds(pr, on_done)
end

---@param pr PullRequest
---@param on_done fun(entries: PullsDiffstatEntry[]|nil, err: string|nil)
---@return { cancel: fun() }|nil
function M.fetch_diffstat(pr, on_done)
	local pr_api = require("atlas.pulls.providers.bitbucket.api.pullrequests")
	return pr_api.fetch_diffstat(pr, on_done)
end

---@param pr PullRequest
---@param source "main"|"panel"|nil
---@param on_done fun(result: PullsActionResult|nil)
function M.open_actions(pr, source, on_done)
	local actions = require("atlas.pulls.providers.bitbucket.actions")
	local ctx = {
		pr = pr,
		source = source,
	}

	actions.open(ctx, function(result, _)
		if result == nil then
			on_done(nil)
			return
		end
		on_done({ changed_pr = result.changed_pr, message = result.message })
	end)
end

function M.search()
	local actions = require("atlas.pulls.providers.bitbucket.actions")
	actions.run("search", { source = "main" }, function() end)
end

return M
