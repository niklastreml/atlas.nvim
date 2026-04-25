local M = {}

local icons = require("atlas.ui.shared.icons")
local table_tree = require("atlas.ui.components.table_tree")
local helper = require("atlas.issues.ui.main.helper")

local function text_or(v, fallback)
	if type(v) == "string" and v ~= "" then
		return v
	end
	return fallback
end

---@param issue Issue
---@param width integer
---@param extra_rows IssuesPanelHeaderRow[]|nil
---@return string[], table[]
function M.render(issue, width, extra_rows)
	local issue_type = type(issue.type) == "table" and issue.type.name or "Unknown"
	local key = text_or(issue.key, "")
	local title = text_or(issue.summary, "")
	local status = text_or(issue.status, "Unknown")
	local assignee_name = type(issue.assignee) == "table" and issue.assignee.display_name or "Unassigned"
	local reporter_name = type(issue.reporter) == "table" and issue.reporter.display_name or "Unknown"
	local priority = text_or(issue.priority, "-")
	local priority_icon = icons.issues_priority(priority)

	local type_icon = icons.issues_type(issue_type)
	local user_icon = icons.general("user")

	local type_key_line = string.format(" %s %s %s", type_icon, issue_type, key)
	local title_line = " " .. title

	local rows = {
		{
			k1 = "Status:",
			v1 = status,
			v1_hl = helper.status_hl(issue.status_id),
			k2 = "Priority:",
			v2 = string.format("%s %s", priority_icon, priority),
			v2_hl = helper.priority_hl(issue.priority),
		},
		{
			k1 = "Assignee:",
			v1 = string.format("%s %s", user_icon, assignee_name),
			v1_hl = helper.person_hl(type(issue.assignee) == "table" and issue.assignee.display_name or nil),
			k2 = "Reporter:",
			v2 = string.format("%s %s", user_icon, reporter_name),
			v2_hl = helper.person_hl(type(issue.reporter) == "table" and issue.reporter.display_name or nil),
		},
	}

	for _, row in ipairs(extra_rows or {}) do
		table.insert(rows, row)
	end

	local table_lines, _, table_spans = table_tree.render({
		columns = {
			{ key = "k1", name = "", can_grow = false },
			{ key = "v1", name = "", can_grow = true },
			{ key = "k2", name = "", can_grow = false },
			{ key = "v2", name = "", can_grow = true, grow_last = true },
		},
		rows = rows,
		width = width,
		margin = 1,
		show_header = false,
		column_gap = 2,
		fill = true,
		cell_hl = function(row, col)
			if col.key == "k1" or col.key == "k2" then
				local label = col.key == "k1" and row.k1 or row.k2
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

	local lines = { type_key_line, title_line, "" }
	for _, l in ipairs(table_lines) do
		table.insert(lines, l)
	end
	table.insert(lines, "")

	local spans = {
		{ line = 0, line_hl_group = "AtlasPanelHeaderBg" },
		{ line = 1, line_hl_group = "AtlasPanelHeaderBg" },
		{
			line = 0,
			start_col = 1,
			end_col = #(string.format("%s %s", type_icon, issue_type)) + 1,
			hl_group = helper.issue_type_hl(issue_type),
		},
		{ line = 1, start_col = 1, end_col = #title_line, hl_group = "Normal" },
	}

	if key ~= "" then
		local ks = type_key_line:find(key, 1, true)
		if ks then
			table.insert(spans, {
				line = 0,
				start_col = ks - 1,
				end_col = ks - 1 + #key,
				hl_group = "AtlasJiraKey",
			})
		end
	end

	for _, span in ipairs(table_spans) do
		table.insert(spans, {
			line = span.line + 3,
			start_col = span.start_col,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end

	return lines, spans
end

return M
