---@class BitbucketRepoTagsTabState
---@field repo table|nil
---@field tags BitbucketRepositoryTags|"loading"|nil
---@field line_map table<number, table>

---@class BitbucketRepoTagsTabState
local M = {
	repo = nil,
	tags = nil,
	line_map = {},
}

function M.reset()
	M.repo = nil
	M.tags = nil
	M.line_map = {}
end

return M
