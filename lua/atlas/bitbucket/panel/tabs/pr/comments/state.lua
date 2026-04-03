---@class BitbucketPRCommentTreeNode
---@field comment BitbucketPRCommentEntry
---@field children BitbucketPRCommentTreeNode[]

---@class BitbucketPRCommentsTabState
---@field pr BitbucketPR|nil
---@field comments BitbucketPRCommentTreeNode[]|"loading"|nil
---@field line_map table<number, table>

---@class BitbucketPRCommentsTabState
local M = {
	pr = nil,
	comments = nil,
	line_map = {},
}

function M.reset()
	M.pr = nil
	M.comments = nil
	M.line_map = {}
end

return M
