local M = {
	---@type JiraIssue|nil
	issue = nil,
	---@type table|"loading"|nil
	adf_description = nil,
	---@type string|"loading"|nil
	md_description = nil,
	---@type "markdown"|"raw"
	view_mode = "markdown",
	line_map = {},
}

function M.reset()
	M.issue = nil
	M.adf_description = nil
	M.md_description = nil
	M.view_mode = "markdown"
	M.line_map = {}
end

return M
