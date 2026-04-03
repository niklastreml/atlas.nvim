---@class BitbucketRepoOverviewTabState
---@field repo table|nil
---@field readme string|"loading"|nil
---@field line_map table<number, table>

---@class BitbucketRepoOverviewTabState
local M = {
	repo = nil,
	readme = nil,
	line_map = {},
}

function M.reset()
	M.repo = nil
	M.readme = nil
	M.line_map = {}
end

return M
