---@class BitbucketPROverviewTabState
---@field pr BitbucketPR|nil
---@field detail BitbucketPRDetail|"loading"|nil
---@field diffstat BitbucketPRDiffstat|"loading"|nil
---@field line_map table<number, table>

---@class BitbucketPROverviewTabState
local M = {
	pr = nil,
	detail = nil,
	diffstat = nil,
	line_map = {},
}

function M.reset()
	M.pr = nil
	M.detail = nil
	M.diffstat = nil
	M.line_map = {}
end

return M
