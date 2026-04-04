---@class JiraIssueGroup
---@field issue JiraIssue
---@field children JiraIssue[]

---@class JiraState
---@field active_view JiraViewConfig|nil
---@field current_view JiraViewConfig|nil
---@field is_loading boolean
---@field error string|nil
---@field current_user JiraUser|nil
---@field issues JiraIssue[]|nil
---@field issue_tree JiraIssueGroup[]|nil
---@field line_map table<number, table>
---@field latest_request_tokens table<string, integer>
---@field request_seq integer
---@field reloading_issue_keys table<string, integer>
---@field reload_spinner_frame string

---@type JiraState
local M = {
	active_view = nil,
	current_view = nil,
	is_loading = false,
	error = nil,
	current_user = nil,
	issues = nil,
	issue_tree = nil,
	line_map = {},
	latest_request_tokens = {},
	request_seq = 0,
	reloading_issue_keys = {},
	reload_spinner_frame = "⠋",
}

return M
