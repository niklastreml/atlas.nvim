local M = {
	---@type JiraIssue|nil
	issue = nil,
	---@type JiraIssueHistoryEntry[]|nil
	history_items = nil,
	---@type boolean
	is_loading = false,
	line_map = {},
}

function M.reset()
	M.issue = nil
	M.history_items = nil
	M.is_loading = false
	M.line_map = {}
end

return M
