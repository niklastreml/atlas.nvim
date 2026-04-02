---@class JiraState
---@field active_view JiraViewConfig|nil
---@field current_view JiraViewConfig|nil
---@field is_loading boolean
---@field error string|nil
---@field current_user JiraUser|nil
---@field issues JiraIssue[]|nil
---@field issue_tree table[]|nil
---@field line_map table<number, table>
---@field latest_request_tokens table<string, integer>
---@field request_seq integer

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
}

return M
