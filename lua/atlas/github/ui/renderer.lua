local M = {}

local config = require("atlas.config")
local icons = require("atlas.ui.icons")
local state = require("atlas.github.state")
local header = require("atlas.ui.components.header")
local navbar = require("atlas.ui.components.navbar")
local table_view = require("atlas.ui.components.table")
local utils = require("atlas.utils")

local function fake_rows()
	return {
		{
			kind = "repo",
			key = "emrearmagan/atlas.nvim",
			name = "emrearmagan/atlas.nvim",
			expanded = true,
			children = {
				{
					kind = "pr",
					id = "#90",
					name = "Add provider payload renderer",
					title = "Add provider payload renderer",
					author = "emrearmagan",
					checks = "passing",
					updated = "48m",
					_item = { kind = "pr", id = 90 },
				},
				{
					kind = "pr",
					id = "#87",
					name = "Refine footer alignment",
					title = "Refine footer alignment",
					author = "team-bot",
					checks = "pending",
					updated = "3h",
					_item = { kind = "pr", id = 87 },
				},
			},
			_item = { kind = "repo", key = "emrearmagan/atlas.nvim" },
		},
	}
end

---@param opts { width: number, height: number }
---@param rerender fun(view: "bitbucket"|"github"|"jira")
function M.render(opts, rerender)
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
			active = key == state.active_view_key,
		})
	end

	local actions = {
		{ label = string.format(" %s Refresh (r) ", icons.action("refresh")), hl_group = "AtlasTitleGithub" },
	}

	local lines, spans = {}, {}
	local line_map = {}

	utils.append_block(
		lines,
		spans,
		header.render({
			width = opts.width,
			icon = icons.provider("github"),
			title = "Github",
			hl_group = "AtlasTitleGithub",
		})
	)

	utils.append_block(
		lines,
		spans,
		navbar.render({
			width = width,
			items = nav_items,
			actions = actions,
			active_hl = "AtlasTitleGithub",
		})
	)

	table.insert(lines, "")

	local tbl_lines, tbl_map, tbl_spans = table_view.render({
		width = width,
		margin = 0,
		columns = {
			{ key = "name", name = "Repo / PR", min_width = 30 },
			{ key = "id", name = "ID", min_width = 10 },
			{ key = "author", name = "Author", min_width = 14 },
			{ key = "checks", name = "Checks", min_width = 12 },
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
			if row.kind == "repo" and col.key == "name" then
				return "AtlasTextPositive"
			end
			if row.kind == "pr" and col.key == "checks" then
				if row.checks == "passing" then
					return "AtlasTextPositive"
				end
				if row.checks == "pending" then
					return "AtlasTextWarning"
				end
				return "AtlasTextMuted"
			end
			return "AtlasText"
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
