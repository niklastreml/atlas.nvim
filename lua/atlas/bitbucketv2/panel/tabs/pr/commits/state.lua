---@class BitbucketPRCommitsTabState
---@field pr BitbucketPR|nil
---@field commits BitbucketPRCommits|"loading"|nil
---@field line_map table<number, table>

---@class BitbucketPRCommitsTabState
local M = {
	pr = nil,
	commits = nil,
	line_map = {},
}

function M.reset()
	M.pr = nil
	M.commits = nil
	M.line_map = {}
end

return M
