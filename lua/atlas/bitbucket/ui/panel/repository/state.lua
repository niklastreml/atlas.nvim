---@class BitbucketRepositoryPanelState
---@field current_repo table|nil
---@field current_detail BitbucketRepositoryDetail|"loading"|nil
---@field current_tab "overview"|"branches"|"tags"|"commits"
local M = {
	current_repo = nil,
	current_detail = nil,
	current_tab = "overview",
}

---@param repo table|nil
function M.set_current(repo)
	M.current_repo = repo
	M.current_detail = nil
end

---@param detail BitbucketRepositoryDetail|nil
function M.set_current_detail(detail)
	M.current_detail = detail
end

function M.set_current_detail_loading()
	M.current_detail = "loading"
end

---@param tab "overview"|"branches"|"tags"|"commits"
function M.set_current_tab(tab)
	if tab == "overview" or tab == "branches" or tab == "tags" or tab == "commits" then
		M.current_tab = tab
	end
end

function M.reset()
	M.current_repo = nil
	M.current_detail = nil
	M.current_tab = "overview"
end

return M
