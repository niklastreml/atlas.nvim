---@class PullsOverviewState
---@field reviewers PullsReviewer[]|"loading"|string|nil
---@field builds PullsBuild[]|"loading"|string|nil
---@field diffstat PullsDiffstatEntry[]|"loading"|string|nil
local M = {
	reviewers = nil,
	builds = nil,
	diffstat = nil,
}

function M.reset()
	M.reviewers = nil
	M.builds = nil
	M.diffstat = nil
end

---@return boolean
function M.any_loading()
	return M.reviewers == "loading" or M.builds == "loading" or M.diffstat == "loading"
end

return M
