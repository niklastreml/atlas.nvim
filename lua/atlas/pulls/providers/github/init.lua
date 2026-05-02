local M = {}

local icons = require("atlas.ui.shared.icons")

---@class GitHubProvider : PullsProvider
M.id = "github"
M.name = "GitHub"
M.icon = icons.pulls_provider("github", "provider")
M.hl_group = "AtlasGitHubTheme"
M.panel = require("atlas.pulls.providers.github.ui.panel")

function M.setup()
	require("atlas.pulls.providers.github.highlights").setup()
end


---@return AtlasGitHubConfig
local function github_config()
	local config = require("atlas.config")
	return ((config.options.pulls or {}).providers or {}).github or {}
end

---@param on_done fun(user: PullsUser|nil, err: string|nil)
function M.fetch_user(on_done)
	local users_api = require("atlas.pulls.providers.github.api.users")
	local state = require("atlas.pulls.providers.github.state")

	users_api.fetch_user(function(user, err)
		if user then
			state.current_user = user
		end
		on_done(user, err)
	end)
end

---@param view AtlasPullsViewConfig
---@param opts PullsFetchOpts
---@param on_done fun(groups: PullsGroup[], err: string[]|nil)
---@return { cancel: fun() }|nil
function M.fetch_pullrequests(view, opts, on_done)
	local pr_api = require("atlas.pulls.providers.github.api.pullrequests")
	local gh_state = require("atlas.pulls.providers.github.state")
	---@cast view AtlasGitHubViewConfig

	local search = view.search or ""
	if search == "" then
		vim.schedule(function()
			on_done({}, { "No search query configured for view" })
		end)
		return nil
	end

	local query = search
	if not query:find("is:pr") then
		query = "is:pr " .. query
	end

	local pulls_state = require("atlas.pulls.state")
	local f = pulls_state.status_filters or {}
	local open, merged, declined = f.OPEN, f.MERGED, f.DECLINED
	if open and not merged and not declined then
		query = query .. " is:open"
	elseif merged and not open and not declined then
		query = query .. " is:merged"
	elseif declined and not open and not merged then
		query = query .. " is:closed -is:merged"
	elseif merged and declined and not open then
		query = query .. " is:closed"
	end

	gh_state.last_search_query = query

	return pr_api.search_prs(query, on_done, {
		force_load = opts.force_load == true,
		limit = opts.pagelen,
	})
end

---@param pr PullRequest
---@param opts PullsFetchOpts
---@param on_done fun(pr: PullRequest|nil, err: string|nil)
---@return { cancel: fun() }|nil
function M.fetch_pullrequest(pr, opts, on_done)
	local pr_api = require("atlas.pulls.providers.github.api.pullrequests")

	local owner = pr.workspace or ""
	local repo = pr.repo or ""
	local number = pr.id

	if owner == "" or repo == "" then
		vim.schedule(function()
			on_done(nil, "Missing repository info")
		end)
		return nil
	end

	return pr_api.get_pr(owner, repo, number, on_done, {
		force_load = opts.force_load == true,
	})
end

---@param pr PullRequest
---@param opts { force_refresh: boolean|nil }|nil
---@param on_done fun(description: string|nil, err: string|nil)
---@return { cancel: fun() }|nil
function M.fetch_description(pr, opts, on_done)
	local cli = require("atlas.pulls.providers.github.api.cli")
	local repo_slug = pr.repo_full_name or ""

	if repo_slug == "" then
		vim.schedule(function()
			on_done(nil, "Missing repo")
		end)
		return nil
	end

	local cache_key = string.format("github:desc:%s:%s", repo_slug, tostring(pr.id))
	opts = opts or {}

	if not opts.force_refresh then
		local cached, ok = cli.get_cache(cache_key)
		if ok then
			on_done(cached, nil)
			return nil
		end
	end

	return cli.gh({
		"pr", "view", tostring(pr.id),
		"--repo", repo_slug,
		"--json", "body",
	}, function(result, err)
		if err or type(result) ~= "table" then
			on_done(nil, err or "Failed to fetch description")
			return
		end

		local body = tostring(result.body or "")
		cli.set_cache(cache_key, body)
		on_done(body, nil)
	end)
end

---@param pr PullRequest
---@param opts { force_refresh: boolean|nil }|nil
---@param on_done fun(reviewers: PullsReviewer[]|nil, err: string|nil)
---@return { cancel: fun() }|nil
function M.fetch_reviewers(pr, opts, on_done)
	local cli = require("atlas.pulls.providers.github.api.cli")
	local repo_slug = pr.repo_full_name or ""

	if repo_slug == "" then
		vim.schedule(function()
			on_done(nil, "Missing repo")
		end)
		return nil
	end

	local cache_key = string.format("github:reviewers:%s:%s", repo_slug, tostring(pr.id))
	opts = opts or {}

	if not opts.force_refresh then
		local cached, ok = cli.get_cache(cache_key)
		if ok then
			on_done(cached, nil)
			return nil
		end
	end

	return cli.gh({
		"pr", "view", tostring(pr.id),
		"--repo", repo_slug,
		"--json", "latestReviews,reviewRequests",
	}, function(result, err)
		if err or type(result) ~= "table" then
			on_done(nil, err or "Failed to fetch reviewers")
			return
		end

		local reviewers = {}
		for _, review in ipairs(result.latestReviews or {}) do
			local login = type(review.author) == "table" and tostring(review.author.login or "") or ""
			if login ~= "" then
				local gh_state = tostring(review.state or ""):upper()
				local decision = "pending"
				if gh_state == "APPROVED" then
					decision = "approved"
				elseif gh_state == "CHANGES_REQUESTED" then
					decision = "changes_requested"
				end
				table.insert(reviewers, { name = login, nickname = login, decision = decision })
			end
		end

		for _, req in ipairs(result.reviewRequests or {}) do
			local login = type(req) == "table" and tostring(req.login or "") or ""
			if login ~= "" then
				local already = false
				for _, r in ipairs(reviewers) do
					if r.name == login then
						already = true
						break
					end
				end
				if not already then
					table.insert(reviewers, { name = login, nickname = login, decision = "pending" })
				end
			end
		end

		cli.set_cache(cache_key, reviewers)
		on_done(reviewers, nil)
	end)
end

---@param pr PullRequest
---@param on_done fun(builds: PullsBuild[]|nil, err: string|nil)
---@return { cancel: fun() }|nil
function M.fetch_builds(pr, on_done)
	local cli = require("atlas.pulls.providers.github.api.cli")
	local repo_slug = pr.repo_full_name or ""

	if repo_slug == "" then
		vim.schedule(function()
			on_done(nil, "Missing repo")
		end)
		return nil
	end

	return cli.gh({
		"pr", "checks", tostring(pr.id),
		"--repo", repo_slug,
		"--json", "name,state,bucket,link,workflow",
	}, function(result, err)
		if err then
			-- exit code 1 with no checks is not an error
			if err:find("no checks") or err:find("no status checks") then
				on_done({}, nil)
				return
			end
			on_done(nil, err)
			return
		end

		if type(result) ~= "table" then
			on_done({}, nil)
			return
		end

		local BUCKET_MAP = {
			pass = "SUCCESSFUL",
			fail = "FAILED",
			pending = "INPROGRESS",
			skipping = "STOPPED",
			cancel = "STOPPED",
		}

		local builds = {}
		for _, check in ipairs(result) do
			table.insert(builds, {
				name = tostring(check.name or ""),
				state = BUCKET_MAP[tostring(check.bucket or "")] or "INPROGRESS",
				url = check.link and tostring(check.link) or nil,
				key = check.workflow and tostring(check.workflow) or nil,
			})
		end

		on_done(builds, nil)
	end)
end

---@param pr PullRequest
---@param opts { force_refresh: boolean|nil }|nil
---@param on_done fun(entries: PullsDiffstatEntry[]|nil, err: string|nil)
---@return { cancel: fun() }|nil
function M.fetch_diffstat(pr, opts, on_done)
	local cli = require("atlas.pulls.providers.github.api.cli")
	local repo_slug = pr.repo_full_name or ""

	if repo_slug == "" then
		vim.schedule(function()
			on_done(nil, "Missing repo")
		end)
		return nil
	end

	local cache_key = string.format("github:diffstat:%s:%s", repo_slug, tostring(pr.id))
	opts = opts or {}

	if not opts.force_refresh then
		local cached, ok = cli.get_cache(cache_key)
		if ok then
			on_done(cached, nil)
			return nil
		end
	end

	return cli.gh({
		"pr", "view", tostring(pr.id),
		"--repo", repo_slug,
		"--json", "files",
	}, function(result, err)
		if err or type(result) ~= "table" then
			on_done(nil, err or "Failed to fetch files")
			return
		end

		local entries = {}
		for _, file in ipairs(result.files or {}) do
			local additions = tonumber(file.additions) or 0
			local deletions = tonumber(file.deletions) or 0
			local status = "modified"
			if additions > 0 and deletions == 0 then
				status = "added"
			elseif additions == 0 and deletions > 0 then
				status = "removed"
			end

			table.insert(entries, {
				status = status,
				path = tostring(file.path or ""),
				old_path = nil,
				lines_added = additions,
				lines_removed = deletions,
			})
		end

		cli.set_cache(cache_key, entries)
		on_done(entries, nil)
	end)
end

---@param pr PullRequest
---@param opts { force_refresh: boolean|nil }|nil
---@param on_done fun(entries: PullsActivityEntry[]|nil, err: string|nil)
---@return { cancel: fun() }|nil
function M.fetch_activity(pr, opts, on_done)
	local cli = require("atlas.pulls.providers.github.api.cli")
	local repo_slug = pr.repo_full_name or ""

	if repo_slug == "" then
		vim.schedule(function()
			on_done(nil, "Missing repo")
		end)
		return nil
	end

	local cache_key = string.format("github:activity:%s:%s", repo_slug, tostring(pr.id))
	opts = opts or {}

	if not opts.force_refresh then
		local cached, ok = cli.get_cache(cache_key)
		if ok then
			on_done(cached, nil)
			return nil
		end
	end

	return cli.gh({ "api", string.format("repos/%s/issues/%s/timeline", repo_slug, tostring(pr.id)) }, function(result, err)
		if err or type(result) ~= "table" then
			on_done(nil, err or "Failed to fetch activity")
			return
		end

		local entries = {}
		for _, item in ipairs(result) do
			local event = tostring(item.event or "")
			local actor_login = type(item.actor) == "table" and tostring(item.actor.login or "") or ""
			local date = tostring(item.created_at or item.submitted_at or "")

			if event == "commented" then
				table.insert(entries, {
					kind = "comment",
					actor = actor_login ~= "" and { name = actor_login, id = "", username = actor_login, nickname = actor_login } or nil,
					date = date,
					content_raw = tostring(item.body or ""),
				})
			elseif event == "reviewed" then
				local state_label = tostring(item.state or ""):lower()
				table.insert(entries, {
					kind = "approval",
					actor = actor_login ~= "" and { name = actor_login, id = "", username = actor_login, nickname = actor_login } or nil,
					date = date,
					content_raw = state_label ~= "" and state_label or nil,
				})
			elseif event == "closed" or event == "merged" or event == "reopened" then
				table.insert(entries, {
					kind = "update",
					actor = actor_login ~= "" and { name = actor_login, id = "", username = actor_login, nickname = actor_login } or nil,
					date = date,
					content_raw = event,
				})
			elseif event == "head_ref_force_pushed" then
				table.insert(entries, {
					kind = "update",
					actor = actor_login ~= "" and { name = actor_login, id = "", username = actor_login, nickname = actor_login } or nil,
					date = date,
					content_raw = "force pushed",
				})
			end
		end

		cli.set_cache(cache_key, entries)
		on_done(entries, nil)
	end)
end

---@param pr PullRequest
---@param opts { force_refresh: boolean|nil }|nil
---@param on_done fun(comments: PullsComment[]|nil, err: string|nil)
---@return { cancel: fun() }|nil
function M.fetch_comments(pr, opts, on_done)
	local cli = require("atlas.pulls.providers.github.api.cli")
	local repo_slug = pr.repo_full_name or ""

	if repo_slug == "" then
		vim.schedule(function()
			on_done(nil, "Missing repo")
		end)
		return nil
	end

	local cache_key = string.format("github:comments:%s:%s", repo_slug, tostring(pr.id))
	opts = opts or {}

	if not opts.force_refresh then
		local cached, ok = cli.get_cache(cache_key)
		if ok then
			on_done(cached, nil)
			return nil
		end
	end

	return cli.gh({ "api", string.format("repos/%s/issues/%s/comments", repo_slug, tostring(pr.id)) }, function(result, err)
		if err or type(result) ~= "table" then
			on_done(nil, err or "Failed to fetch comments")
			return
		end

		local comments = {}
		for _, raw in ipairs(result) do
			local user = raw.user or {}
			table.insert(comments, {
				id = raw.id,
				parent_id = nil,
				author = {
					name = tostring(user.login or ""),
					nickname = tostring(user.login or ""),
					id = tostring(user.id or ""),
				},
				content_raw = tostring(raw.body or ""),
				created_on = tostring(raw.created_at or ""),
				deleted = false,
				inline = nil,
				url = nil,
				html_url = tostring(raw.html_url or ""),
			})
		end

		cli.set_cache(cache_key, comments)
		on_done(comments, nil)
	end)
end

---@param pr PullRequest
---@param opts { force_refresh: boolean|nil }|nil
---@param on_done fun(commits: PullsCommit[]|nil, err: string|nil)
---@return { cancel: fun() }|nil
function M.fetch_commits(pr, opts, on_done)
	local cli = require("atlas.pulls.providers.github.api.cli")
	local repo_slug = pr.repo_full_name or ""

	if repo_slug == "" then
		vim.schedule(function()
			on_done(nil, "Missing repo")
		end)
		return nil
	end

	local cache_key = string.format("github:commits:%s:%s", repo_slug, tostring(pr.id))
	opts = opts or {}

	if not opts.force_refresh then
		local cached, ok = cli.get_cache(cache_key)
		if ok then
			on_done(cached, nil)
			return nil
		end
	end

	return cli.gh({
		"pr", "view", tostring(pr.id),
		"--repo", repo_slug,
		"--json", "commits",
	}, function(result, err)
		if err or type(result) ~= "table" then
			on_done(nil, err or "Failed to fetch commits")
			return
		end

		local commits = {}
		for _, raw in ipairs(result.commits or {}) do
			local hash = tostring(raw.oid or "")
			local authors = raw.authors or {}
			local author_name = ""
			local author_login = ""
			if #authors > 0 then
				author_name = tostring(authors[1].name or authors[1].login or "")
				author_login = tostring(authors[1].login or "")
			end

			table.insert(commits, {
				hash = hash,
				short_hash = #hash > 7 and hash:sub(1, 7) or hash,
				message = tostring(raw.messageHeadline or raw.messageBody or ""),
				author_name = author_name,
				author_nickname = author_login,
				date = tostring(raw.authoredDate or raw.committedDate or ""),
				html_url = repo_slug ~= "" and string.format("https://github.com/%s/commit/%s", repo_slug, hash) or nil,
			})
		end

		cli.set_cache(cache_key, commits)
		on_done(commits, nil)
	end)
end

---@param pr PullRequest
---@param opts { force_refresh: boolean|nil }|nil
---@param on_done fun(files: PullsDiffFile[]|nil, err: string|nil)
---@return { cancel: fun() }|nil
function M.fetch_diff(pr, opts, on_done)
	local cli = require("atlas.pulls.providers.github.api.cli")
	local repo_slug = pr.repo_full_name or ""

	if repo_slug == "" then
		vim.schedule(function()
			on_done(nil, "Missing repo")
		end)
		return nil
	end

	local cache_key = string.format("github:diff:%s:%s", repo_slug, tostring(pr.id))
	opts = opts or {}

	if not opts.force_refresh then
		local cached, ok = cli.get_cache(cache_key)
		if ok then
			on_done(cached, nil)
			return nil
		end
	end

	return cli.gh({
		"pr", "diff", tostring(pr.id),
		"--repo", repo_slug,
	}, function(result, err)
		if err then
			on_done(nil, err)
			return
		end

		local diff_text = tostring(result or "")
		local diff_parser = require("atlas.core.git.diff_parser")
		local files = diff_parser.parse(diff_text)

		cli.set_cache(cache_key, files)
		on_done(files, nil)
	end)
end

---@return AtlasPullsViewConfig[]
function M.views()
	local cfg = github_config()
	return cfg.views or {}
end

return M
