---@class PullsFilesTabState
---@field diff PullsDiffFile[]|"loading"|string|nil
---@field collapsed_hunks table<number, boolean>
local M = {
	diff = nil,
	collapsed_hunks = {},
}

function M.reset()
	M.diff = nil
	M.collapsed_hunks = {}
end

---@return boolean
function M.any_loading()
	return M.diff == "loading"
end

return M
