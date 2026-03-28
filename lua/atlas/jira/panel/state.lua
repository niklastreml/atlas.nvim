local M = {
	current_issue_key = nil,
	by_issue = {},
}

---@param issue_key string
function M.ensure(issue_key) end

function M.reset_current() end

return M
