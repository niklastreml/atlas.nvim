---@class BitbucketPRCommentTreeNode
---@field comment BitbucketPRCommentEntry
---@field children BitbucketPRCommentTreeNode[]

---@class BitbucketPRCommentsTabState
---@field pr BitbucketPR|nil
---@field comments BitbucketPRCommentEntry[]|"loading"|nil
---@field tasks BitbucketPRTask[]|"loading"|nil
---@field line_map table<number, table>

---@class BitbucketPRCommentsTabState
local M = {
	pr = nil,
	comments = nil,
	tasks = nil,
	line_map = {},
}

function M.reset()
	M.pr = nil
	M.comments = nil
	M.tasks = nil
	M.line_map = {}
end

return M
