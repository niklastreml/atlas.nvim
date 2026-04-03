---@class BitbucketPRActivityTabState
---@field pr BitbucketPR|nil
---@field activity BitbucketPRActivity|"loading"|nil
---@field line_map table<number, table>

---@class BitbucketPRActivityTabState
local M = {
	pr = nil,
	activity = nil,
	line_map = {},
}

function M.reset()
	M.pr = nil
	M.activity = nil
	M.line_map = {}
end

return M
