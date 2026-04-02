local M = {
	---@type JiraIssue|nil
	issue = nil,
	---@type JiraComment[]|nil
	comments = nil,
	---@type "loading"|nil
	state = nil,
	line_map = {},
}

function M.reset()
	M.issue = nil
	M.comments = nil
	M.state = nil
	M.line_map = {}
end

return M
