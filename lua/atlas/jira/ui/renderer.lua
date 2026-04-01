local M = {}

local config = require("atlas.config")
local icons = require("atlas.ui.icons")
local state = require("atlas.jira.state")
local header = require("atlas.ui.components.header")
local navbar = require("atlas.ui.components.navbar")
local table_view = require("atlas.ui.components.table")
local utils = require("atlas.utils")
local footer = require("atlas.ui.components.footer")

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
	local icon = is_child and "" or icons.jira_type(issue.type)
	local name = is_child and ("  " .. icons.jira_type(issue.type) .. " " .. issue.key .. " " .. issue.summary)
		or (issue.key .. " " .. issue.summary)

	local row = {
		kind = "issue",
		key = issue.key,
		id = issue.key,
		icon = icon,
		name = name,
		status = issue.status,
		status_category = issue.status_category,
		assignee = issue.assignee,
		reporter = issue.reporter,
		priority = issue.priority,
		duedate = issue.duedate or "",
		type = issue.type,
		subtask = issue.subtask,
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
				priority = "",
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
		{ label = string.format(" %s Refresh (R) ", icons.entity("refresh")), hl_group = "AtlasJiraTheme" },
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

		local tbl_lines, tbl_map, tbl_spans = table_view.render({
			width = opts.width,
			margin = 1,
			columns = {
				{ key = "icon", name = "", can_grow = false },
				{ key = "name", name = "Issue", min_width = 30 },
				{ key = "priority", name = "Priority", width = 10, can_grow = false },
				{ key = "duedate", name = "Due", width = 12, can_grow = false },
				{ key = "assignee", name = "Assignee", width = 16, can_grow = false },
				{ key = "reporter", name = "Reporter", width = 16, can_grow = false },
				{ key = "status", name = "Status", width = 14, can_grow = false },
			},
			rows = rows,
			tree = {
				children_key = "children",
				expanded_field = "expanded",
				default_expanded = true,
				indent = "",
				show_indicator = true,
				leaf_prefix = "",
			},
			cell_hl = function(row, col)
				if col.key == "status" then
					if row.status_category == "Done" then
						return "AtlasTextPositive"
					end
					if row.status_category == "In Progress" or row.status_category == "In Arbeit" then
						return "AtlasTextWarning"
					end
					return "AtlasTextMuted"
				end
				if col.key == "priority" or col.key == "duedate" or col.key == "reporter" then
					return "AtlasTextMuted"
				end
				return nil
			end,
		})

		local table_base = #lines
		utils.append_block(lines, spans, { lines = tbl_lines, spans = tbl_spans })

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
