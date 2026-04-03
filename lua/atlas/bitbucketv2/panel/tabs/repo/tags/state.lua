---@class BitbucketRepoTagsTabState
---@field repo table|nil
---@field line_map table<number, table>

---@class BitbucketRepoTagsTabState
local M = {
	repo = nil,
	line_map = {},
}

function M.reset()
	M.repo = nil
	M.line_map = {}
end

return M
