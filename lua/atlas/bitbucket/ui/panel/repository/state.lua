---@class BitbucketRepositoryPanelState
---@field current_repo table|nil
---@field current_detail BitbucketRepositoryDetail|"loading"|nil
---@field current_readme string|"loading"|nil
---@field current_branches BitbucketRepositoryBranches|"loading"|nil
---@field current_tags BitbucketRepositoryTags|"loading"|nil
---@field current_tab "overview"|"branches"|"tags"
local M = {
	current_repo = nil,
	current_detail = nil,
	current_readme = nil,
	current_branches = nil,
	current_tags = nil,
	current_tab = "overview",
}

---@param repo table|nil
function M.set_current(repo)
	M.current_repo = repo
	M.current_detail = nil
	M.current_readme = nil
	M.current_branches = nil
	M.current_tags = nil
end

---@param detail BitbucketRepositoryDetail|nil
function M.set_current_detail(detail)
	M.current_detail = detail
end

function M.set_current_detail_loading()
	M.current_detail = "loading"
end

---@param readme string|nil
function M.set_current_readme(readme)
	M.current_readme = readme
end

function M.set_current_readme_loading()
	M.current_readme = "loading"
end

---@param branches BitbucketRepositoryBranches|nil
function M.set_current_branches(branches)
	M.current_branches = branches
end

function M.set_current_branches_loading()
	M.current_branches = "loading"
end

---@param tags BitbucketRepositoryTags|nil
function M.set_current_tags(tags)
	M.current_tags = tags
end

function M.set_current_tags_loading()
	M.current_tags = "loading"
end

---@param tab "overview"|"branches"|"tags"
function M.set_current_tab(tab)
	if tab == "overview" or tab == "branches" or tab == "tags" then
		M.current_tab = tab
	end
end

function M.reset()
	M.current_repo = nil
	M.current_detail = nil
	M.current_readme = nil
	M.current_branches = nil
	M.current_tags = nil
	M.current_tab = "overview"
end

return M
