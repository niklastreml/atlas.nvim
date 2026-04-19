---@class PullsRepoPanelState
---@field current_repo PullsRepo|nil
---@field current_repo_details PullsRepoDetails|nil
---@field current_tab string
---@field line_map table<integer, table>
---@field loading_details boolean
local M = {
	current_repo = nil,
	current_repo_details = nil,
	current_tab = "overview",
	line_map = {},
	loading_details = false,
}

function M.reset()
	M.current_repo = nil
	M.current_repo_details = nil
	M.current_tab = "overview"
	M.line_map = {}
	M.loading_details = false
end

return M
