local M = {}

local service = require("atlas.pulls.providers.bitbucket.api.service")
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

		local values = (result or {}).values or {}
		---@type BitbucketRepository[]
		local repositories = {}
		for _, raw in ipairs(values) do
			local item = type(raw) == "table" and raw or {}
			local workspace_obj = type(item.workspace) == "table" and item.workspace or {}
			local links = type(item.links) == "table" and item.links or {}
			local mainbranch = type(item.mainbranch) == "table" and item.mainbranch or {}
			local self_link = type(links.self) == "table" and links.self or {}
			local commits_link = type(links.commits) == "table" and links.commits or {}
			local branches_link = type(links.branches) == "table" and links.branches or {}
			local tags_link = type(links.tags) == "table" and links.tags or {}

			table.insert(repositories, {
				uuid = tostring(item.uuid or ""),
				type = tostring(item.type or ""),
				description = tostring(item.description or ""),
				name = tostring(item.name or ""),
				full_name = tostring(item.full_name or ""),
				slug = tostring(item.slug or ""),
				workspace = tostring(workspace_obj.slug or workspace or ""),
				is_private = item.is_private == true,
				updated_on = tostring(item.updated_on or ""),
				links = {
					href = tostring(self_link.href or ""),
					commits = tostring(commits_link.href or ""),
					branches = tostring(branches_link.href or ""),
					tags = tostring(tags_link.href or ""),
				},
				size = tonumber(item.size) or 0,
				created_on = tostring(item.created_on or ""),
				mainbranch = tostring(mainbranch.name or ""),
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
