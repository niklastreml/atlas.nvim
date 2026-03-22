local M = {}

local config = require("atlas.config")
local icons = require("atlas.ui.icons")
local state = require("atlas.bitbucket.state")
local header = require("atlas.ui.components.header")
local navbar = require("atlas.ui.components.navbar")
local footer = require("atlas.ui.components.footer")
local table_view = require("atlas.ui.components.table")
local ui_utils = require("atlas.ui.utils")

local function fake_rows()
	return {
		{
			kind = "pr",
			id = "#142",
			repo_pr = "Refactor auth middleware",
			comments = "6",
			tasks = "2",
			author = "emrearmagan",
			repo = "ws/atlas.nvim",
			updated = "2h",
			_item = { kind = "pr", id = 142, repo = "ws/atlas.nvim" },
		},
		{
			kind = "meta",
			id = "",
			repo_pr = "linux → main",
			comments = "",
			tasks = "",
			author = "",
			repo = "",
			updated = "",
			separator = true,
			_item = { kind = "pr_meta", id = 142, repo = "ws/atlas.nvim" },
		},
		{
			kind = "pr",
			id = "#138",
			repo_pr = "Fix cache invalidation",
			comments = "1",
			tasks = "0",
			author = "team-bot",
			repo = "ws/atlas.nvim",
			updated = "1d",
			_item = { kind = "pr", id = 138, repo = "ws/atlas.nvim" },
		},
		{
			kind = "meta",
			id = "",
			repo_pr = "feature/cache-fix → main",
			comments = "",
			tasks = "",
			author = "",
			repo = "",
			updated = "",
			separator = true,
			_item = { kind = "pr_meta", id = 138, repo = "ws/atlas.nvim" },
		},
		{
			kind = "pr",
			id = "#77",
			repo_pr = "Improve table docs",
			comments = "3",
			tasks = "1",
			author = "emrearmagan",
			repo = "ws/dockyard.nvim",
			updated = "4h",
			_item = { kind = "pr", id = 77, repo = "ws/dockyard.nvim" },
		},
		{
			kind = "meta",
			id = "",
			repo_pr = "docs/table-example → main",
			comments = "",
			tasks = "",
			author = "",
			repo = "",
			updated = "",
			separator = true,
			_item = { kind = "pr_meta", id = 77, repo = "ws/dockyard.nvim" },
		},
		{
			kind = "pr",
			id = "#75",
			repo_pr = "Polish footer alignment",
			comments = "5",
			tasks = "2",
			author = "team-bot",
			repo = "ws/dockyard.nvim",
			updated = "7h",
			_item = { kind = "pr", id = 75, repo = "ws/dockyard.nvim" },
		},
		{
			kind = "meta",
			id = "",
			repo_pr = "ui/footer-polish → main",
			comments = "",
			tasks = "",
			author = "",
			repo = "",
			updated = "",
			_item = { kind = "pr_meta", id = 75, repo = "ws/dockyard.nvim" },
		},
	}
end

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
			{ key = "id", name = "ID", min_width = 8, can_grow = false },
			{ key = "repo_pr", name = "PR", min_width = 34 },
			{ key = "comments", name = "󰅺", min_width = 2, can_grow = false },
			{ key = "tasks", name = "☐", min_width = 2, can_grow = false },
			{ key = "author", name = "Author", min_width = 3, can_grow = false },
			{ key = "repo", name = "Repo", min_width = 5, can_grow = false },
			{ key = "updated", name = "󰥔", min_width = 4, can_grow = false },
		},
		rows = fake_rows(),
		cell_hl = function(row, col)
			if row.kind == "meta" and col.key == "repo_pr" then
				return "AtlasTextSubtle"
			end
			return nil
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
			{ text = "? help", hl_group = "AtlasTextMuted", align = "right" },
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
