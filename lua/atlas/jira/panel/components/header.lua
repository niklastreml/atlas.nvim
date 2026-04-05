local M = {}

local helper = require("atlas.jira.ui.helper")
local icons = require("atlas.ui.icons")
local table_tree_v2 = require("atlas.ui.components.table_tree_v2")
local chips = require("atlas.jira.panel.components.chips")
local utils = require("atlas.utils")

local function text_or(v, fallback)
	if type(v) == "string" and v ~= "" then
		return v
	end
	return fallback
end

---@param user JiraUser|nil
---@param fallback string
---@return string
local function user_name_or(user, fallback)
	if type(user) == "table" and type(user.display_name) == "string" and user.display_name ~= "" then
		return user.display_name
	end
	return fallback
end

---@param issue JiraIssue
---@param width integer
---@param opts { custom_fields?: JiraCustomFieldValue[], table_fields?: JiraCustomFieldValue[] }|nil
---@return string[]
---@return table[]
function M.render(issue, width, opts)
	opts = opts or {}
	local issue_type = text_or(type(issue and issue.type) == "table" and issue.type.name or nil, "Unknown")
	local key = text_or(issue and issue.key, "")
	local title = text_or(issue and issue.summary, "")
	local status = text_or(issue and issue.status, "Unknown")
	local assignee = user_name_or(issue and issue.assignee, "Unassigned")
	local reporter = text_or(issue and issue.reporter, "Unknown")
	local priority = text_or(issue and issue.priority, "-")
	local priority_icon = icons.jira_icon(priority)
	local story_points = issue and issue.story_points
	local story_points_text = type(story_points) == "number" and tostring(story_points) or "-"
	local due_date = utils.format_date(issue and issue.duedate)
	local due_date_text = due_date ~= "" and due_date or "-"
	local parent_key = type(issue and issue.parent) == "table" and text_or(issue.parent.key, "-") or "-"

	local type_icon = icons.jira_icon(type(issue and issue.type) == "table" and issue.type.name or nil)
	local user_icon = icons.entity("user")
	local priority_text = string.format("%s %s", priority_icon, priority)

	local type_key_line = string.format(" %s %s %s", type_icon, issue_type, key)
	local title_line = " " .. title

	local rows = {
		{
			k1 = "Status:",
			v1 = status,
			v1_hl = helper.status_hl(issue and issue.status_id),
			k2 = "Priority:",
			v2 = priority_text,
			v2_hl = helper.priority_hl(issue and issue.priority),
		},
		{
			k1 = "Assignee:",
			v1 = string.format("%s %s", user_icon, assignee),
			v1_hl = helper.person_hl(type(issue and issue.assignee) == "table" and issue.assignee.display_name or nil),
			k2 = "Reporter:",
			v2 = string.format("%s %s", user_icon, reporter),
			v2_hl = helper.person_hl(issue and issue.reporter),
		},
	}

	if type(opts.table_fields) == "table" then
		for _, field in ipairs(opts.table_fields) do
			table.insert(rows, {
				k1 = string.format("%s:", field.name),
				v1 = field.formatted,
				v1_hl = field.hl_group,
				k2 = "",
				v2 = "",
				v2_hl = nil,
			})
		end
	end

	local table_lines, _, table_spans = table_tree_v2.render({
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
					{
						start_col = 0,
						end_col = #label,
						hl_group = "AtlasTextMuted",
					},
				}
			end

			if col.key == "v1" then
				return {
					{
						start_col = 0,
						end_col = #row.v1,
						hl_group = row.v1_hl,
					},
				}
			end

			if col.key == "v2" then
				return {
					{
						start_col = 0,
						end_col = #row.v2,
						hl_group = row.v2_hl,
					},
				}
			end
			return nil
		end,
	})

	local lines = {
		type_key_line,
		title_line,
		"",
	}
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
			hl_group = helper.issue_type_hl(type(issue and issue.type) == "table" and issue.type.name or nil),
		},
		{ line = 1, start_col = 1, end_col = #title_line, hl_group = helper.issue_title_hl(title) },
	}

	if key ~= "" then
		local ks = type_key_line:find(key, 1, true)
		if ks then
			table.insert(spans, {
			line = 0,
			start_col = ks - 1,
			end_col = ks - 1 + #key,
			hl_group = helper.issue_hl(key),
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

	local chip_items = {
		{
			text = string.format("%s %s", icons.entity("branch"), parent_key),
			hl_group = parent_key ~= "-" and "AtlasJiraChipParent" or "AtlasTextMuted",
			active = true,
		},
		{
			text = string.format("%s %s", icons.entity("story_points"), story_points_text),
			hl_group = type(story_points) == "number" and "AtlasJiraChipStoryPoints" or "AtlasTextMuted",
			active = true,
		},
		{
			text = string.format("%s %s", icons.entity("created"), due_date_text),
			hl_group = due_date ~= "" and "AtlasJiraChipDueDate" or "AtlasTextMuted",
			active = true,
		},
	}

	if type(opts.custom_fields) == "table" then
		for _, field in ipairs(opts.custom_fields) do
			table.insert(chip_items, {
				text = field.formatted,
				hl_group = field.hl_group or "AtlasChipActive",
				active = true,
			})
		end
	end

	local chip_line, chip_spans = chips.render(chip_items, width, 1)

	if chip_line ~= "" then
		table.insert(lines, chip_line)
		for _, span in ipairs(chip_spans) do
			table.insert(spans, {
				line = #lines - 1,
				start_col = span.start_col,
				end_col = span.end_col,
				hl_group = span.hl_group,
			})
		end
	end

	return lines, spans
end

return M
