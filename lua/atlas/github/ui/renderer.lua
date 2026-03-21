local M = {}

local config = require("atlas.config")
local icons = require("atlas.ui.icons")
local state = require("atlas.github.state")
local header = require("atlas.ui.components.header")
local navbar = require("atlas.ui.components.navbar")
local footer = require("atlas.ui.components.footer")
local ui_utils = require("atlas.ui.utils")

function M.render(width, height)
	local views = (config.options.github and config.options.github.views) or {}
	if state.active_view_key == nil and views[1] then
		state.active_view_key = views[1].key or views[1].name
	end

	local nav_items = {}
	for _, v in ipairs(views) do
		local key = v.key or v.name
		local label = v.key and string.format("%s (%s)", v.name, v.key) or v.name
		table.insert(nav_items, {
			label = label,
			icon = icons.provider("github"),
			active = key == state.active_view_key,
		})
	end

	local actions = {
		{ label = string.format(" %s Refresh (r) ", icons.action("refresh")), hl_group = "AtlasTitleGithub" },
	}

	local lines, spans = {}, {}

	ui_utils.append_block(lines, spans, header.render({
		width = width,
		icon = icons.provider("github"),
		title = "Github",
		hl_group = "AtlasTitleGithub",
	}))

	ui_utils.append_block(lines, spans, navbar.render({
		width = width,
		items = nav_items,
		actions = actions,
		active_hl = "AtlasTitleGithub",
	}))

	table.insert(lines, "")
	table.insert(lines, "  Github board - phase 1")
	table.insert(lines, "")
	table.insert(lines, "  Table comes in phase 2.")

	local footer_block = footer.render({
		width = width,
		segments = {
			{ text = "Pull Requests", hl_group = "AtlasFooterText" },
			{ text = "|", hl_group = "AtlasFooterMuted" },
			{ text = "Review Queue", hl_group = "AtlasFooterInfo" },
			{ text = "? help", hl_group = "AtlasFooterMuted", align = "right" },
			{ text = "r refresh", hl_group = "AtlasFooterText", align = "right" },
		},
	})

	local footer_rows = #footer_block.lines
	local max_content_rows = math.max((height or 0) - footer_rows, 0)
	local fill = max_content_rows - #lines

	if fill > 0 then
		for _ = 1, fill do
			table.insert(lines, "")
		end
	end

	ui_utils.append_block(lines, spans, footer_block)

	return lines, spans, state.line_map
end

return M
