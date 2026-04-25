local M = {}

local icons = require("atlas.ui.shared.icons")
local helper = require("atlas.issues.ui.main.helper")
local table_tree = require("atlas.ui.components.table_tree")

---@param fields IssueEditorFields
---@param assignees IssueUser[]|"loading"|nil
---@param spinner_instance SpinnerInstance|nil
---@return string
---@return boolean
local function get_assignee_display(fields, assignees, spinner_instance)
	if assignees == "loading" then
		local frame = spinner_instance and spinner_instance:current_frame() or "⠋"
		return frame .. " Loading...", true
	end

	if fields.assignee then
		return icons.general("user") .. " " .. fields.assignee.display_name, false
	end

	return icons.general("user") .. " Unassigned", false
end

---@param fields IssueEditorFields
---@param issue_types IssueType[]|"loading"|nil
---@param spinner_instance SpinnerInstance|nil
---@return string
---@return boolean
local function get_issue_type_display(fields, issue_types, spinner_instance)
	if issue_types == "loading" then
		local frame = spinner_instance and spinner_instance:current_frame() or "⠋"
		return frame .. " Loading...", true
	end

	if fields.issue_type and fields.issue_type.name ~= "" then
		local name = fields.issue_type.name
		return string.format("%s %s", icons.issues_type(name), name), false
	end

	return "None", false
end

---@param width integer
---@param fields IssueEditorFields
---@param assignees IssueUser[]|"loading"|nil
---@param issue_types IssueType[]|"loading"|nil
---@param spinner_instance SpinnerInstance|nil
---@return string[]
---@return { line: integer, start_col: integer, end_col: integer, hl_group: string }[]
function M.render_meta_lines(width, fields, assignees, issue_types, spinner_instance)
	local user_icon = icons.general("user")
	local assignee_text, is_loading = get_assignee_display(fields, assignees, spinner_instance)
	local issue_type_text, issue_type_loading = get_issue_type_display(fields, issue_types, spinner_instance)
	local reporter_name = fields.reporter and fields.reporter.display_name or "Unknown"
	local project_name = fields.project or "Unknown"

	local assignee_hl
	if is_loading then
		assignee_hl = "AtlasTextMuted"
	elseif fields.assignee then
		assignee_hl = helper.person_hl(fields.assignee.display_name)
	else
		assignee_hl = helper.person_hl(nil)
	end

	local rows = {
		{
			k1 = "Assignee:",
			v1 = assignee_text,
			v1_hl = assignee_hl,
			k2 = "Reporter:",
			v2 = string.format("%s %s", user_icon, reporter_name),
			v2_hl = helper.person_hl(reporter_name),
		},
		{
			k1 = "Project:",
			v1 = string.format("%s %s", icons.issues_provider("jira", "provider"), project_name),
			v1_hl = "AtlasProjectKey",
			k2 = "Type:",
			v2 = issue_type_text,
			v2_hl = issue_type_loading and "AtlasTextMuted"
				or helper.issue_type_hl(fields.issue_type and fields.issue_type.name or nil),
		},
	}

	local lines, _, spans = table_tree.render({
		columns = {
			{ key = "k1", name = "", can_grow = false },
			{ key = "v1", name = "", can_grow = true },
			{ key = "k2", name = "", can_grow = false },
			{ key = "v2", name = "", can_grow = true, grow_last = true },
		},
		rows = rows,
		width = width,
		margin = 0,
		show_header = false,
		column_gap = 2,
		fill = true,
		cell_hl = function(row, col)
			if col.key == "k1" or col.key == "k2" then
				local label = col.key == "k1" and row.k1 or row.k2
				if label == "" then
					return nil
				end
				return {
					{ start_col = 0, end_col = #label, hl_group = "AtlasTextMuted" },
				}
			end

			if col.key == "v1" then
				return {
					{ start_col = 0, end_col = #row.v1, hl_group = row.v1_hl },
				}
			end

			if col.key == "v2" and row.v2 ~= "" then
				return {
					{ start_col = 0, end_col = #row.v2, hl_group = row.v2_hl },
				}
			end

			return nil
		end,
	})

	return lines, spans
end

return M
