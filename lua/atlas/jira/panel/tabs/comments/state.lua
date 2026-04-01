local M = {
	---@type JiraIssue|nil
	issue = nil,
	comments = nil,
	line_map = {},
}

function M.reset()
	M.issue = nil
	M.comments = nil
	M.line_map = {}
end

return M
