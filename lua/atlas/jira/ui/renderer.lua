local M = {}

local config = require("atlas.config")
local icons = require("atlas.ui.icons")
local state = require("atlas.jira.state")
local header = require("atlas.ui.components.header")
local navbar = require("atlas.ui.components.navbar")
local table_view = require("atlas.ui.components.table")
local utils = require("atlas.utils")
local footer = require("atlas.ui.components.footer")

local function fake_rows()
	return {
		{
			kind = "project",
			key = "ATLAS",
			name = "ATLAS",
			expanded = true,
			children = {
				{
					kind = "issue",
					id = "ATLAS-101",
					name = "Implement Jira panel architecture",
					title = "Implement Jira panel architecture",
					assignee = "emrearmagan",
					status = "In Progress",
					priority = "High",
					type = "Story",
					updated = "2h",
					_item = { kind = "issue", key = "ATLAS-101" },
				},
				{
					kind = "issue",
					id = "ATLAS-102",
					name = "Add comment line map support",
					title = "Add comment line map support",
					assignee = "emrearmagan",
					status = "To Do",
					priority = "Medium",
					type = "Task",
					updated = "5h",
					_item = { kind = "issue", key = "ATLAS-102" },
				},
				{
					kind = "issue",
					id = "ATLAS-103",
					name = "Fix ADF rendering for code blocks",
					title = "Fix ADF rendering for code blocks",
					assignee = "Unassigned",
					status = "To Do",
					priority = "Low",
					type = "Bug",
					updated = "1d",
					_item = { kind = "issue", key = "ATLAS-103" },
				},
				{
					kind = "issue",
					id = "ATLAS-104",
					name = "Add worklog tab to panel",
					title = "Add worklog tab to panel",
					assignee = "team-bot",
					status = "Review",
					priority = "Medium",
					type = "Task",
					updated = "3h",
					_item = { kind = "issue", key = "ATLAS-104" },
				},
				{
					kind = "issue",
					id = "ATLAS-105",
					name = "Refactor transition action flow",
					title = "Refactor transition action flow",
					assignee = "emrearmagan",
					status = "Done",
					priority = "High",
					type = "Story",
					updated = "6h",
					_item = { kind = "issue", key = "ATLAS-105" },
				},
			},
			_item = { kind = "project", key = "ATLAS" },
		},
	}
end

---@param opts { width: number, height: number }
function M.render(opts)
	footer.set_items({
		{ text = "Issues", hl_group = "AtlasFooterText" },
		{ text = "|", hl_group = "AtlasFooterText" },
		{ text = "r refresh", hl_group = "AtlasFooterText" },
	})

	local views = (config.options.jira and config.options.jira.views) or {}
	if state.active_view_key == nil and views[1] then
		state.active_view_key = views[1].key or views[1].name
	end

	local nav_items = {}
	for _, v in ipairs(views) do
		local key = v.key or v.name
		local label = v.key and string.format("%s (%s)", v.name, v.key) or v.name
		table.insert(nav_items, {
			label = label,
			active = key == state.active_view_key,
		})
	end

	local actions = {
		{ label = string.format(" %s Refresh (r) ", icons.entity("refresh")), hl_group = "AtlasJiraTheme" },
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

	local tbl_lines, tbl_map, tbl_spans = table_view.render({
		width = opts.width,
		margin = 0,
		columns = {
			{ key = "name", name = "Project / Issue", min_width = 30 },
			{ key = "id", name = "Key", min_width = 12 },
			{ key = "assignee", name = "Assignee", min_width = 16 },
			{ key = "status", name = "Status", min_width = 14 },
			{ key = "updated", name = "Updated", min_width = 8 },
		},
		rows = fake_rows(),
		tree = {
			children_key = "children",
			expanded_field = "expanded",
			default_expanded = true,
			indent = "  ",
			show_indicator = true,
			leaf_prefix = "└─ ",
		},
		cell_hl = function(row, col)
			if row.kind == "project" and col.key == "name" then
				return "AtlasTextPositive"
			end
			if row.kind == "issue" and col.key == "status" then
				return "AtlasTextWarning"
			end
			return "AtlasTextMuted"
		end,
	})

	local table_base = #lines
	utils.append_block(lines, spans, { lines = tbl_lines, highlights = tbl_spans })
	for lnum, node in pairs(tbl_map) do
		line_map[table_base + lnum] = node
	end

	return lines, spans, line_map
end

return M
