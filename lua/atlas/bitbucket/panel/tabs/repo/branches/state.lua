---@class BitbucketRepoBranchesTabState
---@field repo table|nil
---@field branches BitbucketRepositoryBranches|"loading"|nil
---@field line_map table<number, table>

---@class BitbucketRepoBranchesTabState
local M = {
	repo = nil,
	branches = nil,
	line_map = {},
}

function M.reset()
	M.repo = nil
	M.branches = nil
	M.line_map = {}
end

return M
