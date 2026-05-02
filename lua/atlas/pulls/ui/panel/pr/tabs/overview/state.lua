---@class PullsOverviewState
---@field reviewers PullsReviewer[]|"loading"|string|nil
---@field builds PullsBuild[]|"loading"|string|nil
---@field description string|"loading"|nil
local M = {
	reviewers = nil,
	builds = nil,
	description = nil,
}

function M.reset()
	M.reviewers = nil
	M.builds = nil
	M.description = nil
end

---@return boolean
function M.any_loading()
	return M.reviewers == "loading" or M.builds == "loading" or M.description == "loading"
end

return M
