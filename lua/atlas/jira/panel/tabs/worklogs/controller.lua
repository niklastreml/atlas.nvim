local M = {}
local state = require("atlas.jira.panel.tabs.worklogs.state")

---@param issue JiraIssue|nil
function M.fetch_if_needed(issue)
	state.issue = issue
	state.line_map = {}
end

function M.refresh() end

function M.add_worklog() end

return M
