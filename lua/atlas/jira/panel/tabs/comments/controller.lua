local M = {}
local state = require("atlas.jira.panel.tabs.comments.state")

---@param issue JiraIssue|nil
function M.fetch_if_needed(issue)
	state.issue = issue
	state.line_map = {}
end

function M.refresh() end

function M.add_comment() end

function M.edit_comment_under_cursor() end

function M.delete_comment_under_cursor() end

return M
