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
---@field collapsed_issue_keys table<string, boolean>
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
	collapsed_issue_keys = {},
	latest_request_tokens = {},
	request_seq = 0,
	reloading_issue_keys = {},
	reload_spinner_frame = "⠋",
}

---@param issue_key string|nil
---@return boolean
function M.toggle_issue_collapsed(issue_key)
	issue_key = type(issue_key) == "string" and issue_key or ""
	if issue_key == "" then
		return false
	end

	local issue_tree = M.issue_tree or {}
	local has_children = false
	for _, group in ipairs(issue_tree) do
		local group_key = type(group.issue) == "table" and tostring(group.issue.key or "") or ""
		if group_key == issue_key then
			has_children = type(group.children) == "table" and #group.children > 0
			break
		end
	end
	if not has_children then
		return false
	end

	M.collapsed_issue_keys = M.collapsed_issue_keys or {}
	if M.collapsed_issue_keys[issue_key] == true then
		M.collapsed_issue_keys[issue_key] = nil
	else
		M.collapsed_issue_keys[issue_key] = true
	end

	return true
end

---@return boolean
function M.toggle_current_issue_collapsed()
	local navigation = require("atlas.ui.navigation")
	local node = navigation.current_item()
	if type(node) ~= "table" or node.kind ~= "issue" then
		return false
	end

	local issue = type(node._issue) == "table" and node._issue or nil
	local issue_key = type(issue) == "table" and tostring(issue.key or "") or ""
	return M.toggle_issue_collapsed(issue_key)
end

return M
