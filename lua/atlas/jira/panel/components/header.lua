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

local function approvers_value(v, user_icon)
	if type(v) ~= "table" or #v == 0 then
		return string.format("%s None", user_icon), {}
	end

	local chunks = {}
	for i, name in ipairs(v) do
		if i == 1 then
			table.insert(chunks, string.format("%s %s", user_icon, name))
		else
			table.insert(chunks, name)
		end
	end

	return table.concat(chunks, ", "), v
end

---@param issue JiraIssue
---@param width integer
---@return string[]
---@return table[]
function M.render(issue, width)
	local issue_type = text_or(issue and issue.type, "Unknown")
	local key = text_or(issue and issue.key, "")
	local title = text_or(issue and issue.summary, "")
	local status = text_or(issue and issue.status, "Unknown")
	local assignee = text_or(issue and issue.assignee, "Unassigned")
	local reporter = text_or(issue and issue.reporter, "Unknown")
	local story_points = issue and issue.story_points
	local story_points_text = type(story_points) == "number" and tostring(story_points) or "-"
	local due_date = utils.format_date(issue and issue.duedate)
	local due_date_text = due_date ~= "" and due_date or "-"
	local parent_key = type(issue and issue.parent) == "table" and text_or(issue.parent.key, "-") or "-"

	local type_icon = icons.jira_icon(issue and issue.type)
	local user_icon = icons.entity("user")
	local approvers, approver_names = approvers_value(issue and issue.approvers, user_icon)

	local type_key_line = string.format(" %s %s %s", type_icon, issue_type, key)
	local title_line = " " .. title

	local rows = {
		{
			k1 = "Status:",
			v1 = status,
			v1_hl = helper.status_hl(issue and issue.status_id),
			k2 = "Assignee:",
			v2 = string.format("%s %s", user_icon, assignee),
			v2_hl = helper.person_hl(issue and issue.assignee),
		},
		{
			k1 = "Reporter:",
			v1 = string.format("%s %s", user_icon, reporter),
			v1_hl = helper.person_hl(issue and issue.reporter),
			k2 = "Approvers:",
			v2 = approvers,
			approver_names = approver_names,
			v2_hl = "AtlasTextMuted",
		},
	}

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
				if row.k2 == "Approvers:" and type(row.approver_names) == "table" and #row.approver_names > 0 then
					local parts = {}
					local offset = 0
					for i, name in ipairs(row.approver_names) do
						local chunk
						if i == 1 then
							chunk = string.format("%s %s", user_icon, name)
						else
							chunk = name
						end
						local chunk_len = #chunk
						table.insert(parts, {
							start_col = offset,
							end_col = offset + chunk_len,
							hl_group = helper.person_hl(name),
						})
						offset = offset + chunk_len
						if i < #row.approver_names then
							table.insert(parts, {
								start_col = offset,
								end_col = offset + 2,
								hl_group = "AtlasTextMuted",
							})
							offset = offset + 2
						end
					end
					return parts
				end

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
		{
			line = 0,
			start_col = 1,
			end_col = #(string.format("%s %s", type_icon, issue_type)) + 1,
			hl_group = helper.issue_type_hl(issue and issue.type),
		},
		{ line = 1, start_col = 1, end_col = #title_line, hl_group = helper.issue_title_hl() },
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

	local chip_line, chip_spans = chips.render({
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
	}, width, 1)

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
