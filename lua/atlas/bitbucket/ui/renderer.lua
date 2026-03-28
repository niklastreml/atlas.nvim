local M = {}

local config = require("atlas.config")
local icons = require("atlas.ui.icons")
local state = require("atlas.bitbucket.state")
local helper = require("atlas.bitbucket.ui.helper")
local header = require("atlas.ui.components.header")
local navbar = require("atlas.ui.components.navbar")
local table_view = require("atlas.ui.components.table")
local utils = require("atlas.utils")
local highlights = require("atlas.ui.highlights")
local footer = require("atlas.ui.components.footer")

---@param table_lines string[]
---@param table_map table<number, table>
---@param table_spans table[]
local function add_pr_id_spans(table_lines, table_map, table_spans)
	for lnum, item in pairs(table_map or {}) do
		if type(item) == "table" and item.kind == "pr" then
			local line = table_lines[lnum] or ""
			local s, e = string.find(line, "#%d+")
			if s and e then
				table.insert(table_spans, {
					line = lnum - 1,
					start_col = s - 1,
					end_col = e,
					hl_group = "AtlasTextMuted",
				})
			end
		end
	end
end

-- Layout: compact
--   [pr] #123 Title                        c t author repo created updated
--       source/branch -> target/branch     (meta row + separator line)
---@param opts { width: number, height: number }
---@param repos BitbucketRepoPRGroup[]
---@return string[]
---@return table[]
---@return table<number, table>
local function build_plain_content(opts, repos)
	local table_data = helper.build_compact_table(repos)
	local tbl_lines, tbl_map, tbl_spans = table_view.render({
		width = opts.width,
		margin = 1,
		columns = table_data.columns,
		rows = table_data.rows,
		cell_hl = helper.cell_hl,
	})
	add_pr_id_spans(tbl_lines, tbl_map, tbl_spans)

	return tbl_lines, tbl_spans, tbl_map
end

-- Layout: plain
--   [pr] #123 Title                        c t author repo source->target created updated
--   (single row per PR, no meta row)
---@param opts { width: number, height: number }
---@param repos BitbucketRepoPRGroup[]
---@return string[]
---@return table[]
---@return table<number, table>
local function build_plain_singleline_content(opts, repos)
	local table_data = helper.build_plain_table(repos)
	local tbl_lines, tbl_map, tbl_spans = table_view.render({
		width = opts.width,
		margin = 1,
		columns = table_data.columns,
		rows = table_data.rows,
		cell_hl = helper.cell_hl,
	})
	add_pr_id_spans(tbl_lines, tbl_map, tbl_spans)

	return tbl_lines, tbl_spans, tbl_map
end

-- Layout: grouped
--   [repo heading]
--   [pr] #123 Title                        c t author repo created updated
--       source/branch -> target/branch     (uses compact rows under each repo heading)
---@param opts { width: number, height: number }
---@param repos BitbucketRepoPRGroup[]
---@return string[]
---@return table[]
---@return table<number, table>
local function build_grouped_content(opts, repos)
	local lines, spans = {}, {}
	local line_map = {}

	for i, group in ipairs(repos or {}) do
		local repo_line = string.format(" %s %s", icons.entity("repo"), group.full_name)
		local repo_hl = highlights.dynamic_for(group.full_name) or "AtlasTextMuted"
		table.insert(lines, repo_line)
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #repo_line,
			hl_group = repo_hl,
		})
		table.insert(lines, "")

		local table_data = helper.build_grouped_table(group)
		if #table_data.rows == 0 then
			table.insert(lines, "(no pull requests)")
		else
			local tbl_lines, tbl_map, tbl_spans = table_view.render({
				width = opts.width,
				margin = 1,
				columns = table_data.columns,
				rows = table_data.rows,
				cell_hl = helper.cell_hl,
			})
			add_pr_id_spans(tbl_lines, tbl_map, tbl_spans)

			local table_base = #lines
			utils.append_block(lines, spans, { lines = tbl_lines, highlights = tbl_spans })
			for lnum, node in pairs(tbl_map) do
				line_map[table_base + lnum] = node
			end
		end

		if i < #repos then
			table.insert(lines, "")
			table.insert(lines, "")
		end
	end

	return lines, spans, line_map
end

---@param lines string[]
---@param spans table[]
---@param width number
---@param views BitbucketViewConfig[]
local function render_header(lines, spans, width, views)
	utils.append_block(
		lines,
		spans,
		header.render({
			width = width,
			icon = icons.provider("bitbucket"),
			title = "Bitbucket",
			hl_group = "AtlasBitbucketTheme",
		})
	)

	local nav_items = {}
	for _, v in ipairs(views) do
		local key = v.key or v.name
		local label = v.key and string.format("%s (%s)", v.name, v.key) or v.name
		table.insert(nav_items, {
			label = label,
			active = state.active_view ~= nil and key == state.active_view.key,
		})
	end

	local actions = {
		{ label = string.format(" Refresh (r) "), hl_group = "AtlasBitbucketTheme" },
	}

	utils.append_block(
		lines,
		spans,
		navbar.render({
			width = width,
			items = nav_items,
			actions = actions,
			active_hl = "AtlasBitbucketTheme",
		})
	)
end

---@param opts { width: number, height: number }
function M.render(opts)
	local views = (config.options.bitbucket and config.options.bitbucket.views) or {}

	local lines, spans = {}, {}
	local line_map = {}

	render_header(lines, spans, opts.width, views)
	table.insert(lines, "")

	if state.error then
		table.insert(lines, "Error loading pull requests: " .. state.error)
	elseif state.is_loading then
		table.insert(lines, "Loading...")
	else
		local layout = state.active_view and state.active_view.layout or "compact"
		local body_lines, body_spans, body_map
		if layout == "grouped" then
			body_lines, body_spans, body_map = build_grouped_content(opts, state.repos or {})
		elseif layout == "plain" then
			body_lines, body_spans, body_map = build_plain_singleline_content(opts, state.repos or {})
		else
			body_lines, body_spans, body_map = build_plain_content(opts, state.repos or {})
		end

		local body_base = #lines
		utils.append_block(lines, spans, { lines = body_lines, highlights = body_spans })
		for lnum, node in pairs(body_map) do
			line_map[body_base + lnum] = node
		end

		footer.set_items(helper.build_footer_items(state.repos))
	end

	return lines, spans, line_map
end

return M
