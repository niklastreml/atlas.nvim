---@class PullsPanelState
---@field current_pr PullRequest|nil
---@field current_repo PullsRepo|nil
---@field current_tab string
---@field line_map table<integer, table>
local M = {
	current_pr = nil,
	current_repo = nil,
	current_tab = "overview",
	line_map = {},
}

function M.reset()
	M.current_pr = nil
	M.current_repo = nil
	M.current_tab = "overview"
	M.line_map = {}
end

return M
