---@class BitbucketRepositoryPanelState
---@field current_repo table|nil
---@field current_tab "overview"|"branches"|"tags"|"commits"
local M = {
	current_repo = nil,
	current_tab = "overview",
}

---@param repo table|nil
function M.set_current(repo)
	M.current_repo = repo
end

---@param tab "overview"|"branches"|"tags"|"commits"
function M.set_current_tab(tab)
	if tab == "overview" or tab == "branches" or tab == "tags" or tab == "commits" then
		M.current_tab = tab
	end
end

function M.reset()
	M.current_repo = nil
	M.current_tab = "overview"
end

return M
