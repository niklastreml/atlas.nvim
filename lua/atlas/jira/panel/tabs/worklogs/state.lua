local M = {
	---@type JiraIssue|nil
	issue = nil,
	worklogs = nil,
	line_map = {},
}

function M.reset()
	M.issue = nil
	M.worklogs = nil
	M.line_map = {}
end

return M
