local M = {
	---@type JiraIssue|nil
	current_issue = nil,
	---@type "overview"|"comments"|"worklogs"
	current_tab = "overview",
	line_map = {},
}

---@param issue JiraIssue|nil
function M.set_current(issue)
	M.current_issue = issue
	M.current_tab = "overview"
	M.line_map = {}
end

---@param tab "overview"|"comments"|"worklogs"
function M.set_current_tab(tab)
	M.current_tab = tab
	M.line_map = {}
end

function M.reset()
	M.current_issue = nil
	M.current_tab = "overview"
	M.line_map = {}
end

return M
