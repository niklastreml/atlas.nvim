local M = {
	---@type JiraIssue|nil
	issue = nil,
	issue_detail = nil,
	line_map = {},
}

function M.reset()
	M.issue = nil
	M.issue_detail = nil
	M.line_map = {}
end

return M
