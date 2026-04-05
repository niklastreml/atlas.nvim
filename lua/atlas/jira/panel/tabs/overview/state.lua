---@class JiraCustomFieldValue
---@field name string
---@field formatted string
---@field hl_group string|nil
---@field display "table"|"chip"

local M = {
	---@type JiraIssue|nil
	issue = nil,
	---@type table|"loading"|nil
	adf_description = nil,
	---@type string|"loading"|nil
	md_description = nil,
	---@type "markdown"|"raw"
	view_mode = "markdown",
	---@type JiraCustomFieldValue[]|nil
	custom_fields = nil,
	line_map = {},
}

function M.reset()
	M.issue = nil
	M.adf_description = nil
	M.md_description = nil
	M.view_mode = "markdown"
	M.custom_fields = nil
	M.line_map = {}
end

return M
