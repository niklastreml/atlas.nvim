---@class BitbucketPRFilesTabState
---@field pr BitbucketPR|nil
---@field diffstat BitbucketPRDiffstat|"loading"|nil
---@field diff BitbucketPRDiff|"loading"|nil
---@field line_map table<number, table>

---@class BitbucketPRFilesTabState
local M = {
	pr = nil,
	diffstat = nil,
	diff = nil,
	line_map = {},
}

function M.reset()
	M.pr = nil
	M.diffstat = nil
	M.diff = nil
	M.line_map = {}
end

return M
