local M = {
	---@type Issue|nil
	issue = nil,
	---@type IssueComment[]|nil
	comments = nil,
	is_loading = false,
	line_map = {},
}

function M.reset()
	M.issue = nil
	M.comments = nil
	M.is_loading = false
	M.line_map = {}
end

function M.any_loading()
	return M.is_loading
end

return M
