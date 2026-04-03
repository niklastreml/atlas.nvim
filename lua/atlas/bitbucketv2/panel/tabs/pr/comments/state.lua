---@class BitbucketPRCommentsTabState
---@field pr BitbucketPR|nil
---@field line_map table<number, table>

---@class BitbucketPRCommentsTabState
local M = {
	pr = nil,
	line_map = {},
}

function M.reset()
	M.pr = nil
	M.line_map = {}
end

return M
