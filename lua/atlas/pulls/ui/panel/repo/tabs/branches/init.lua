---@class PullsRepoBranchesTab : PullsRepoPanelTabModule
local M = {}

---@param repo PullsRepo
---@param width integer
---@return string[], table[], table<integer, table>
function M.render(repo, width)
	return {}, {}, {}
end

return M
