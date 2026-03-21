local M = {}

local config = require("atlas.config")
local icons = require("atlas.ui.icons")
local state = require("atlas.bitbucket.state")
local header = require("atlas.ui.components.header")
local navbar = require("atlas.ui.components.navbar")
local footer = require("atlas.ui.components.footer")
local ui_utils = require("atlas.ui.utils")

function M.render(width, height)
	local views = (config.options.bitbucket and config.options.bitbucket.views) or {}
	if state.active_view_key == nil and views[1] then
		state.active_view_key = views[1].key or views[1].name
	end

	local nav_items = {}
	for _, v in ipairs(views) do
		local key = v.key or v.name
		local label = v.key and string.format("%s (%s)", v.name, v.key) or v.name
		table.insert(nav_items, {
			label = label,
			icon = icons.provider("bitbucket"),
			active = key == state.active_view_key,
		})
	end

	local actions = {
		{ label = string.format(" %s Refresh (r) ", icons.action("refresh")), hl_group = "AtlasTitleBitbucket" },
	}

	local lines, spans = {}, {}

	ui_utils.append_block(
		lines,
		spans,
		header.render({
			width = width,
			icon = icons.provider("bitbucket"),
			title = "Bitbucket",
			hl_group = "AtlasTitleBitbucket",
		})
	)

	ui_utils.append_block(
		lines,
		spans,
		navbar.render({
			width = width,
			items = nav_items,
			actions = actions,
			active_hl = "AtlasTitleBitbucket",
		})
	)

	table.insert(lines, "")
	table.insert(lines, "  Bitbucket board - phase 1")
	table.insert(lines, "")
	table.insert(lines, "  Table comes in phase 2.")

	local footer_block = footer.render({
		width = width,
		segments = {
			{ text = "PRs", hl_group = "AtlasFooterText" },
			{ text = "|", hl_group = "AtlasFooterMuted" },
			{ text = "@emrearmagan", hl_group = "AtlasFooterAccent" },
			{ text = "|", hl_group = "AtlasFooterMuted" },
			{ text = "r: refresh", hl_group = "AtlasFooterText", align = "right" },
			{ text = "r: refresh", hl_group = "AtlasFooterText", align = "right" },
		},
	})

	local footer_rows = #footer_block.lines
	local max_content_rows = math.max(height - footer_rows, 0)
	local fill = max_content_rows - #lines

	if fill > 0 then
		for _ = 1, fill do
			table.insert(lines, "")
		end
	end

	ui_utils.append_block(lines, spans, footer_block)
	return lines, spans, {}
end

return M
