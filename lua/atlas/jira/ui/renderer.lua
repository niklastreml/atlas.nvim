local M = {}

local config = require("atlas.config")
local icons = require("atlas.ui.icons")
local state = require("atlas.jira.state")
local header = require("atlas.ui.components.header")
local navbar = require("atlas.ui.components.navbar")
local table_tree_v2 = require("atlas.ui.components.table_tree_v2")
local utils = require("atlas.utils")
local footer = require("atlas.ui.components.footer")
local highlights = require("atlas.ui.highlights")
local STORY_POINTS_ICON = "󰫢"

---@param issue_type string|nil
---@return string
local function issue_type_hl(issue_type)
	local lower = tostring(issue_type or ""):lower()
	if lower == "bug" then
		return "AtlasLogError"
	end
	if lower == "story" then
		return "AtlasTextPositive"
	end
	if lower == "epic" then
		return "AtlasJiraEpic"
	end
	if lower == "task" or lower == "sub-task" or lower == "subtask" then
		return "AtlasLogInfo"
	end
	return "AtlasTextMuted"
end

---@param row table
---@param col table
---@param ctx { text: string, padded: string, width: integer }
---@return table[]|nil
local function cell_hl(row, col, ctx)
	local issue = row._issue

	if col.key == "name" then
		local spans_for_cell = {}
		local is_child = (tonumber(row._tv2_depth) or 0) > 0

		if is_child and type(issue) == "table" then
			local issue_icon = icons.jira_icon(issue.type)
			local is, ie = ctx.text:find(issue_icon, 1, true)
			if is and ie then
				table.insert(spans_for_cell, {
					start_col = is - 1,
					end_col = ie,
					hl_group = issue_type_hl(issue.type),
				})
			end
		end

		if type(issue) == "table" and type(issue.key) == "string" and issue.key ~= "" then
			local s, e = ctx.text:find(issue.key, 1, true)
			if s and e then
				table.insert(spans_for_cell, {
					start_col = s - 1,
					end_col = e,
					hl_group = is_child and "LineNr" or "AtlasJiraKey",
				})

				if is_child then
					local title_start = e + 2
					if title_start <= #ctx.text then
						table.insert(spans_for_cell, {
							start_col = title_start - 1,
							end_col = #ctx.text,
							hl_group = "Comment",
						})
					end
				end
			end
		end

		local ss, se = ctx.text:find(STORY_POINTS_ICON, 1, true)
		if ss and se then
			table.insert(spans_for_cell, {
				start_col = ss - 1,
				end_col = se,
				hl_group = "AtlasJiraStoryPoints",
			})

			local ns, ne = ctx.text:find("%d+%.?%d*", se + 1)
			if ns and ne then
				table.insert(spans_for_cell, {
					start_col = ns - 1,
					end_col = ne,
					hl_group = "AtlasJiraStoryPoints",
				})
			end
		end

		return #spans_for_cell > 0 and spans_for_cell or nil
	end

	if col.key == "duedate" then
		return nil
	end

	if col.key == "status" then
		local hl_group = highlights.dynamic_for_bg(
			type(issue) == "table" and type(issue.status_id) == "string" and ("jira-status:" .. issue.status_id) or nil
		) or "AtlasTextMuted"
		return {
			{ start_col = 0, end_col = #ctx.padded, hl_group = hl_group },
		}
	end

	if col.key == "icon" then
		local hl_group = type(issue) == "table" and issue_type_hl(issue.type) or "AtlasTextMuted"
		return {
			{ start_col = 0, end_col = #ctx.padded, hl_group = hl_group },
		}
	end

	if col.key == "assignee" then
		local assignee_name = type(issue) == "table" and type(issue.assignee) == "string" and issue.assignee or ""
		local hl_group = assignee_name == "" and "AtlasTextMutedItalic" or highlights.dynamic_for(assignee_name)
		if hl_group == nil then
			return nil
		end
		return {
			{ start_col = 0, end_col = #ctx.padded, hl_group = hl_group },
		}
	end

	if col.key == "reporter" then
		local reporter_name = type(issue) == "table" and type(issue.reporter) == "string" and issue.reporter or ""
		local hl_group = reporter_name == "" and "AtlasTextMutedItalic" or highlights.dynamic_for(reporter_name)
		if hl_group == nil then
			return nil
		end
		return {
			{ start_col = 0, end_col = #ctx.padded, hl_group = hl_group },
		}
	end

	return nil
end

---@param view JiraViewConfig|nil
---@return string
local function view_id(view)
	if view == nil then
		return ""
	end
	return view.key or view.name or ""
end

---@param issue JiraIssue
---@param is_child boolean|nil
---@return table
local function issue_to_row(issue, is_child)
	local icon = is_child and "" or icons.jira_icon(issue.type)
	local title = is_child and (icons.jira_icon(issue.type) .. " " .. issue.key .. " " .. issue.summary)
		or (issue.key .. " " .. issue.summary)
	local story_points = issue.story_points
	local points = ""
	if type(story_points) == "number" then
		points = (story_points % 1 == 0) and tostring(math.floor(story_points)) or tostring(story_points)
	end
	local name = points ~= "" and (title .. "  " .. STORY_POINTS_ICON .. " " .. points) or title
	if is_child then
		name = "  " .. name
	end
	local due_display = utils.format_date(issue.duedate)
	if due_display ~= "" then
		due_display = string.format("%s %s", icons.entity("created"), due_display)
	else
		due_display = ""
	end

	local row = {
		icon = icon,
		name = name,
		duedate = due_display,
		assignee = string.format("%s %s", icons.entity("user"), issue.assignee or "Unassigned"),
		reporter = string.format("%s %s", icons.entity("user"), issue.reporter or "Unknown"),
		status = string.format(" %s ", issue.status),

		expanded = true,
		_item = { kind = "issue", key = issue.key },
		_issue = issue,
		children = {},
	}

	for _, child in ipairs(issue.children or {}) do
		table.insert(row.children, issue_to_row(child, true))
	end

	return row
end

---@param issues JiraIssue[]
---@return table[]
local function issues_to_rows(issues)
	local rows = {}
	for i, issue in ipairs(issues) do
		table.insert(rows, issue_to_row(issue))
		if i < #issues then
			table.insert(rows, {
				kind = "separator",
				icon = "",
				name = "",
				duedate = "",
				assignee = "",
				reporter = "",
				status = "",
			})
		end
	end
	return rows
end

---@param opts { width: number, height: number }
function M.render(opts)
	local views = (config.options.jira and config.options.jira.views) or {}
	local active = state.active_view
	local active_id = view_id(active)

	local nav_items = {}
	for _, v in ipairs(views) do
		local id = view_id(v)
		local label = v.key and string.format("%s (%s)", v.name, v.key) or v.name
		table.insert(nav_items, {
			label = label,
			active = id == active_id,
		})
	end

	local actions = {
		{ label = " Refresh (R) ", hl_group = "AtlasJiraTheme" },
	}

	local lines, spans = {}, {}
	local line_map = {}

	utils.append_block(
		lines,
		spans,
		header.render({
			width = opts.width,
			icon = icons.provider("jira"),
			title = "Jira",
			hl_group = "AtlasJiraTheme",
		})
	)

	utils.append_block(
		lines,
		spans,
		navbar.render({
			width = opts.width,
			items = nav_items,
			actions = actions,
			active_hl = "AtlasJiraTheme",
		})
	)

	table.insert(lines, "")

	if state.error then
		table.insert(lines, "Error: " .. state.error)
	elseif state.is_loading then
		table.insert(lines, "Loading...")
	elseif state.issue_tree == nil or #state.issue_tree == 0 then
		table.insert(lines, "No issues found.")
	else
		local rows = issues_to_rows(state.issue_tree)

		local tbl_lines, tbl_map, tbl_spans = table_tree_v2.render({
			width = opts.width,
			margin = 1,
			columns = {
				{ key = "icon", name = "", can_grow = false, align = "center" },
				{ key = "name", name = "󰌷 Issue" },
				{ key = "duedate", name = "", can_grow = false, align = "center", align_title = true },
				{
					key = "assignee",
					name = string.format("%s Assignee", icons.entity("user")),
					max_width = 22,
					can_grow = false,
				},
				{
					key = "reporter",
					name = string.format("%s Reporter", icons.entity("user")),
					max_width = 22,
					can_grow = false,
				},
				{ key = "status", name = " Status", can_grow = false, align = "center" },
			},
			rows = rows,
			tree = {
				column_key = "icon",
				children_key = "children",
				expanded_field = "expanded",
				default_expanded = true,
				indent = "",
				show_indicator = true,
				leaf_prefix = "",
			},
			cell_hl = cell_hl,
		})

		local table_base = #lines
		utils.append_block(lines, spans, { lines = tbl_lines, highlights = tbl_spans })

		for lnum, node in pairs(tbl_map) do
			line_map[table_base + lnum] = node
		end

		local issue_count = #(state.issues or {})
		local user_name = (state.current_user and state.current_user.display_name) or ""
		local footer_items = {
			{ text = string.format("%d issues", issue_count), hl_group = "AtlasFooterText" },
		}
		if user_name ~= "" then
			table.insert(footer_items, { text = "|", hl_group = "AtlasFooterText" })
			table.insert(footer_items, { text = "@" .. user_name, hl_group = "AtlasFooterText" })
		end
		footer.set_items(footer_items)
	end

	return lines, spans, line_map
end

return M
