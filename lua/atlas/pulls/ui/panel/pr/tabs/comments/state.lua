---@class PullsCommentsTabState
---@field comments PullsComment[]|"loading"|string|nil
local M = {
	comments = nil,
}

function M.reset()
	M.comments = nil
end

---@return boolean
function M.any_loading()
	return M.comments == "loading"
end

return M
