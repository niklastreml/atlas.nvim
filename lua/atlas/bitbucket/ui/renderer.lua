local M = {}

local config = require("atlas.config")
local icons = require("atlas.ui.icons")
local state = require("atlas.bitbucket.state")
local bb_highlights = require("atlas.bitbucket.ui.highlights")
local header = require("atlas.ui.components.header")
local navbar = require("atlas.ui.components.navbar")
local footer = require("atlas.ui.components.footer")
local table_view = require("atlas.ui.components.table")
local ui_utils = require("atlas.ui.utils")

local function fake_rows()
	return {
		{
			kind = "repo",
			key = "ws/atlas.nvim",
			repo_pr = "ws/atlas.nvim",
			name = "ws/atlas.nvim",
			id = "",
			title = "",
			state = "",
			comments = "",
			tasks = "",
			last_updated = "",
			expanded = true,
			children = {
				{
					kind = "pr",
					repo_pr = "#142  Refactor auth middleware",
					id = "#142",
					name = "Refactor auth middleware",
					title = "Refactor auth middleware",
					state = "OPEN",
					comments = " 6 ",
					tasks = " 2 ",
					last_updated = " 2h ",
					_item = { kind = "pr", id = 142 },
				},
				{
					kind = "pr",
					repo_pr = "#138  Fix cache invalidation",
					id = "#138",
					name = "Fix cache invalidation",
					title = "Fix cache invalidation",
					state = "DRAFT",
					comments = " 1 ",
					tasks = " 0 ",
					last_updated = " 1d ",
					_item = { kind = "pr", id = 138 },
				},
			},
			_item = { kind = "repo", key = "ws/atlas.nvim" },
		},
		{
			kind = "repo",
			key = "ws/dockyard.nvim",
			repo_pr = "ws/dockyard.nvim",
			name = "ws/dockyard.nvim",
			id = "",
			title = "",
			state = "",
			comments = "",
			tasks = "",
			last_updated = "",
			expanded = true,
			children = {
				{
					kind = "pr",
					repo_pr = "#77  Improve table docs",
					id = "#77",
					name = "Improve table docs",
					title = "Improve table docs",
					state = "MERGED",
					comments = " 3 ",
					tasks = " 1 ",
					last_updated = " 4h ",
					_item = { kind = "pr", id = 77 },
				},
			},
			_item = { kind = "repo", key = "ws/dockyard.nvim" },
		},
	}
end

function M.render(width, height)
	bb_highlights.setup()

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
	local line_map = {}

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

	local tbl_lines, tbl_map, tbl_spans = table_view.render({
		width = width,
		margin = 0,
		columns = {
			{ key = "repo_pr", name = "Repo / PR", min_width = 56 },
			{ key = "state", name = "", min_width = 8, can_grow = false },
			{ key = "comments", name = "󰅺", min_width = 8, can_grow = false },
			{ key = "tasks", name = "󱓞", min_width = 8, can_grow = false },
			{ key = "last_updated", name = "󰥔", min_width = 8, can_grow = false },
		},
		rows = fake_rows(),
		tree = {
			children_key = "children",
			expanded_field = "expanded",
			default_expanded = true,
			indent = "  ",
			show_indicator = true,
			leaf_prefix = "└─ ",
			separator = "─",
		},
		cell_hl = function(row, col)
			if row.kind == "repo" and col.key == "repo_pr" then
				return "AtlasTextPositive"
			end
			if row.kind == "repo" and col.key ~= "repo_pr" then
				return "AtlasTextMuted"
			end
			if row.kind == "pr" and col.key == "state" then
				if row.state == "OPEN" then
					return "AtlasBitbucketStateOpen"
				end
				if row.state == "DRAFT" then
					return "AtlasBitbucketStateDraft"
				end
				if row.state == "MERGED" then
					return "AtlasBitbucketStateMerged"
				end
			end
			if row.kind == "pr" and (col.key == "comments" or col.key == "tasks") then
				return "AtlasTextMuted"
			end
			return "AtlasText"
		end,
	})

	local table_base = #lines
	ui_utils.append_block(lines, spans, { lines = tbl_lines, highlights = tbl_spans })
	for lnum, node in pairs(tbl_map) do
		line_map[table_base + lnum] = node
	end

	local footer_block = footer.render({
		width = width,
		segments = {
			{ text = "PRs", hl_group = "AtlasFooterText" },
			{ text = "|", hl_group = "AtlasFooterMuted" },
			{ text = "@emrearmagan", hl_group = "AtlasFooterAccent" },
			{ text = "|", hl_group = "AtlasFooterMuted" },
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
	return lines, spans, line_map
end

return M
