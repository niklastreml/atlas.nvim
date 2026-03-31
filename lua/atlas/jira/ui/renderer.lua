local M = {}

local config = require("atlas.config")
local icons = require("atlas.ui.icons")
local state = require("atlas.jira.state")
local normalizer = require("atlas.jira.api.normalizer")
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
	elseif state.issues == nil or #state.issues == 0 then
		table.insert(lines, "No issues found.")
	else
		local tbl_lines, tbl_map, tbl_spans = table_view.render({
			width = opts.width,
			margin = 1,
			columns = {
				{ key = "name", name = "Issue", min_width = 30 },
				{ key = "id", name = "Key", min_width = 12 },
				{ key = "type", name = "Type", min_width = 10 },
				{ key = "assignee", name = "Assignee", min_width = 16 },
				{ key = "status", name = "Status", min_width = 14 },
			},
			rows = state.issue_tree,
			tree = {
				children_key = "children",
				expanded_field = "expanded",
				default_expanded = true,
				indent = "  ",
				show_indicator = true,
				leaf_prefix = "└─ ",
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
				if col.key == "type" then
					return "AtlasTextMuted"
				end
				if col.key == "id" then
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
