---@class BitbucketPullsCommentsTabState
---@field comments PullsComment[]|"loading"|string|nil
---@field tasks BitbucketPRTask[]|"loading"|nil
local M = {
	comments = nil,
	tasks = nil,
}

function M.reset()
	M.comments = nil
	M.tasks = nil
end

---@return boolean
function M.any_loading()
	return M.comments == "loading" or M.tasks == "loading"
end

return M
