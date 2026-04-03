local M = {}

---@param v any
---@return table|nil
local function as_table(v)
	if type(v) == "table" then
		return v
	end
	return nil
end

---@param repo table|nil
---@param workspace string|nil
---@return BitbucketRepository
local function repository_entry(repo, workspace)
	local item = as_table(repo) or {}
	local full_name = tostring(item.full_name or "")
	local workspace_obj = as_table(item.workspace) or {}
	local links = as_table(item.links) or {}
	local repo_slug = tostring(item.slug or "")
	local repo_workspace = tostring(workspace_obj.slug or workspace or "")
	local mainbranch = as_table(item.mainbranch) or {}

	return {
		uuid = tostring(item.uuid or ""),
		type = tostring(item.type or ""),
		description = tostring(item.description or ""),
		name = tostring(item.name or ""),
		full_name = full_name,
		slug = repo_slug,
		workspace = repo_workspace,
		is_private = item.is_private == true,
		updated_on = tostring(item.updated_on or ""),
		links = {
			href = tostring((as_table(links.self) or {}).href or ""),
			commits = tostring((as_table(links.commits) or {}).href or ""),
			branches = tostring((as_table(links.branches) or {}).href or ""),
			tags = tostring((as_table(links.tags) or {}).href or ""),
		},
		size = tonumber(item.size) or 0,
		created_on = tostring(item.created_on or ""),
		mainbranch = tostring(mainbranch.name or ""),
	}
end

---@param values table[]|nil
---@param workspace string|nil
---@return BitbucketRepository[]
function M.workspace_repositories(values, workspace)
	local out = {}

	for _, item in ipairs(values or {}) do
		table.insert(out, repository_entry(item, workspace))
	end

	return out
end

---@param result table|nil
---@param workspace string|nil
---@return BitbucketRepository
function M.repository(result, workspace)
	return repository_entry(result, workspace)
end

---@param result table|nil
---@return BitbucketRepositoryBranches
function M.repository_branches(result)
	local payload = as_table(result) or {}
	local entries = {}

	for _, item in ipairs(payload.values or {}) do
		local branch = as_table(item) or {}
		local target = as_table(branch.target) or {}
		local author = as_table(target.author) or {}
		local user = as_table(author.user) or {}
		local name = user.nickname or user.display_name or author.raw or ""

		table.insert(entries, {
			name = tostring(branch.name or ""),
			hash = tostring(target.hash or ""),
			date = tostring(target.date or ""),
			message = tostring(target.message or ""),
			author = tostring(name),
		})
	end

	return {
		entries = entries,
	}
end

---@param result table|nil
---@return BitbucketRepositoryTags
function M.repository_tags(result)
	local payload = as_table(result) or {}
	local entries = {}

	for _, item in ipairs(payload.values or {}) do
		local tag = as_table(item) or {}
		local target = as_table(tag.target) or {}
		local author = as_table(target.author) or {}
		local user = as_table(author.user) or {}
		local name = user.nickname or user.display_name or author.raw or ""

		table.insert(entries, {
			name = tostring(tag.name or ""),
			hash = tostring(target.hash or ""),
			date = tostring(target.date or ""),
			message = tostring(target.message or ""),
			author = tostring(name),
		})
	end

	return {
		entries = entries,
	}
end

return M
