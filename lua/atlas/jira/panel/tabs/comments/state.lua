local M = {
	---@type JiraIssue|nil
	issue = nil,
	---@type string|"loading"|nil
	comments_text = nil,
	line_map = {},
}

function M.reset()
	M.issue = nil
	M.comments_text = nil
	M.line_map = {}
end

return M
