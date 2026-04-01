local M = {
	---@type JiraIssue|nil
	issue = nil,
	---@type string|"loading"|nil
	worklogs_text = nil,
	line_map = {},
}

function M.reset()
	M.issue = nil
	M.worklogs_text = nil
	M.line_map = {}
end

return M
