local M = {}

local service = require("atlas.bitbucket.api.service")
local repo_normalizer = require("atlas.bitbucket.api.repo_normalizer")
local logger = require("atlas.core.logger")

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

	local query_prefix = ""
	if term ~= "" then
		local escaped_term = term:gsub('"', '\\"')
		local q_expression = string.format('name~"%s"', escaped_term)
		local encoded_q = q_expression:gsub('"', "%%22"):gsub(" ", "%%20")
		query_prefix = string.format("q=%s&", encoded_q)
	end

	local endpoint = string.format("/repositories/%s?%ssort=-updated_on&pagelen=50", workspace, query_prefix)

	logger.loginfo("Bitbucket repo fetch start", {
		workspace = workspace,
		search = term,
	})

	return service.request("GET", endpoint, nil, nil, function(result, err)
		if err then
			logger.logerror("Bitbucket repo fetch failed", {
				workspace = workspace,
				search = term,
				error = err,
			})
			on_done(nil, err)
			return
		end

		local repositories = repo_normalizer.workspace_repositories((result or {}).values, workspace)

		logger.loginfo("Bitbucket repo fetch success", {
			workspace = workspace,
			search = term,
			repo_count = #repositories,
		})

		on_done(repositories, nil)
	end)
end

---@param workspace string
---@param repo_slug string
---@param opts { force_load?: boolean }
---@param on_done fun(detail: BitbucketRepository|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.fetch_detail(workspace, repo_slug, opts, on_done)
	if type(workspace) ~= "string" or workspace == "" then
		on_done(nil, "Missing workspace slug")
		return nil
	end
	if type(repo_slug) ~= "string" or repo_slug == "" then
		on_done(nil, "Missing repository slug")
		return nil
	end

	local endpoint = string.format("/repositories/%s/%s", workspace, repo_slug)
	return service.request("GET", endpoint, nil, nil, function(result, err)
		if err then
			on_done(nil, err)
			return
		end

		local detail = repo_normalizer.repository(result, workspace)
		on_done(detail, nil)
	end)
end

---@param workspace string
---@param repo_slug string
---@param ref string
---@param readme_path string|nil
---@param opts { force_load?: boolean }
---@param on_done fun(readme: string|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.fetch_readme(workspace, repo_slug, ref, readme_path, opts, on_done)
	if type(workspace) ~= "string" or workspace == "" then
		on_done(nil, "Missing workspace slug")
		return nil
	end
	if type(repo_slug) ~= "string" or repo_slug == "" then
		on_done(nil, "Missing repository slug")
		return nil
	end
	if type(ref) ~= "string" or ref == "" then
		on_done(nil, "Missing repository ref")
		return nil
	end

	local path = tostring(readme_path or "")
	if path == "" then
		path = "README.md"
	end

	local encoded_ref = ref:gsub(" ", "%%20")
	local encoded_path = path:gsub(" ", "%%20")
	local endpoint = string.format("/repositories/%s/%s/src/%s/%s", workspace, repo_slug, encoded_ref, encoded_path)

	return service.request_text("GET", endpoint, { Accept = "text/plain" }, nil, function(result, err)
		if err ~= nil then
			on_done(nil, err)
			return
		end

		local text = tostring(result or "")
		on_done(text, nil)
	end)
end

---@param branches_url string
---@param opts { force_load?: boolean }
---@param on_done fun(branches: BitbucketRepositoryBranches|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.fetch_branches(branches_url, opts, on_done)
	if type(branches_url) ~= "string" or branches_url == "" then
		on_done(nil, "Missing branches URL")
		return nil
	end

	return service.request("GET", branches_url, nil, nil, function(result, err)
		if err ~= nil then
			on_done(nil, err)
			return
		end

		local branches = repo_normalizer.repository_branches(result)
		on_done(branches, nil)
	end)
end

---@param tags_url string
---@param opts { force_load?: boolean }
---@param on_done fun(tags: BitbucketRepositoryTags|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.fetch_tags(tags_url, opts, on_done)
	if type(tags_url) ~= "string" or tags_url == "" then
		on_done(nil, "Missing tags URL")
		return nil
	end

	return service.request("GET", tags_url, nil, nil, function(result, err)
		if err ~= nil then
			on_done(nil, err)
			return
		end

		local tags = repo_normalizer.repository_tags(result)
		on_done(tags, nil)
	end)
end

return M
