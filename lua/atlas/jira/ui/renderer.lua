local M = {}

local config = require("atlas.config")
local icons = require("atlas.ui.icons")
local state = require("atlas.jira.state")
local header = require("atlas.ui.components.header")
local navbar = require("atlas.ui.components.navbar")
local ui_utils = require("atlas.ui.utils")

function M.render(width)
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
			icon = icons.provider("jira"),
			active = key == state.active_view_key,
		})
	end

	local actions = {
		{ label = string.format(" %s Refresh (r) ", icons.action("refresh")), hl_group = "AtlasActionRefresh" },
		{ label = string.format(" %s Help (?) ", icons.action("help")), hl_group = "AtlasActionHelp" },
	}

	local lines, spans = {}, {}

	ui_utils.append_block(lines, spans, header.render({
		width = width,
		icon = icons.provider("jira"),
		title = "Jira",
		hl_group = "AtlasTitleJira",
	}))

	ui_utils.append_block(lines, spans, navbar.render({
		width = width,
		items = nav_items,
		actions = actions,
		active_hl = "AtlasTitleJira",
	}))

	table.insert(lines, "")
	table.insert(lines, "  Jira board - phase 1")
	table.insert(lines, "")
	table.insert(lines, "  Table comes in phase 2.")

	return lines, spans, state.line_map
end

return M
