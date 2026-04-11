local M = {}

local config = require("atlas.config")
local icons = require("atlas.ui.utils.icons")
local state = require("atlas.bitbucket.state")
local helper = require("atlas.bitbucket.ui.helper")
local header = require("atlas.ui.components.header")
local navbar = require("atlas.ui.components.navbar")
local table_tree = require("atlas.ui.components.table_tree")
local utils = require("atlas.utils")
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
---@param repos BitbucketPRViewGroup[]
---@return string[]
---@return table[]
---@return table<number, table>
local function build_plain_content(opts, repos)
	local table_data = helper.build_compact_table(repos)
	local tbl_lines, tbl_map, tbl_spans = table_tree.render({
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
--   [repo]
--   [children PR rows using tree renderer]
---@param opts { width: number, height: number }
---@param repos BitbucketPRViewGroup[]
---@return string[]
---@return table[]
---@return table<number, table>
local function build_plain_singleline_content(opts, repos)
	local table_data = helper.build_plain_tree_table(repos)

	local tbl_lines, tbl_map, tbl_spans = table_tree.render({
		width = opts.width,
		margin = 1,
		columns = table_data.columns,
		rows = table_data.rows,
		cell_hl = helper.cell_hl,
		tree = {
			column_key = "name",
			children_key = "children",
			expanded_field = "expanded",
			default_expanded = true,
			indent = "",
			show_indicator = false,
			separator = "─",
		},
	})
	add_pr_id_spans(tbl_lines, tbl_map, tbl_spans)

	return tbl_lines, tbl_spans, tbl_map
end

---@param lines string[]
---@param spans table[]
---@param width number
---@param views BitbucketViewConfig[]
local function render_header(lines, spans, width, views)
	local function view_id_str(v)
		if v == nil then
			return ""
		end
		return tostring(v.key or v.name or "")
	end

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

	local nav_source = {}
	for _, v in ipairs(views or {}) do
		table.insert(nav_source, v)
	end

	--- This just helps adding the active view to the navbar if it doesn't exist in the config views (e.g. from a search result view)
	local active = state.active_view
	local active_id = view_id_str(active)
	local exists = false
	for _, v in ipairs(nav_source) do
		if view_id_str(v) == active_id then
			exists = true
			break
		end
	end
	if active ~= nil and active_id ~= "" and not exists then
		table.insert(nav_source, active)
	end

	local nav_items = {}
	for _, v in ipairs(nav_source) do
		local label = v.key and string.format("%s (%s)", v.name, v.key) or v.name
		table.insert(nav_items, {
			label = label,
			active = view_id_str(v) == active_id,
		})
	end

	local actions = {
		{ label = string.format("Refresh (R)"), hl_group = "AtlasTextMuted" },
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
		local error_text = tostring(state.error or ""):gsub("[\r\n]+", " | ")
		local err_line = "Error: " .. error_text
		utils.append_block(lines, spans, {
			lines = { err_line },
			highlights = {
				{ line = 0, start_col = 0, end_col = #err_line, hl_group = "AtlasLogError" },
			},
		})
	elseif state.is_loading then
		table.insert(lines, "Loading...")
	else
		local layout = state.active_view and state.active_view.layout or "compact"
		local body_lines, body_spans, body_map
		if layout == "plain" then
			body_lines, body_spans, body_map = build_plain_singleline_content(opts, state.repos or {})
		else
			body_lines, body_spans, body_map = build_plain_content(opts, state.repos or {})
		end

		local body_base = #lines
		utils.append_block(lines, spans, { lines = body_lines, highlights = body_spans })
		for lnum, node in pairs(body_map) do
			line_map[body_base + lnum] = node
		end

		footer.set_items(helper.build_footer_items(state.repos, state.current_user))
	end

	return lines, spans, line_map
end

---@param pr BitbucketPR
---@return string[], table[]
function M.pr_popup_content(pr)
	local id = tostring(pr.id or "")
	local title = tostring(pr.title or "")
	local author_name = tostring((pr.author and pr.author.name) or "Unknown")
	local repo_name = tostring(pr.repo_full_name or "")

	local lines = {
		string.format(" #%s: %s", id, title),
		"",
		string.format(" State:    %s", tostring(pr.state or "-")),
		string.format(" Author:   %s", author_name),
		string.format(" Repo:     %s", repo_name ~= "" and repo_name or "-"),
		string.format(
			" Branch:   %s -> %s",
			tostring((pr.source or {}).branch or "?"),
			tostring((pr.destination or {}).branch or "?")
		),
		string.format(" Comments: %s", tostring(pr.comments or 0)),
		string.format(" Tasks:    %s", tostring(pr.tasks or 0)),
		string.format(" Updated:  %s", utils.relative_time(pr.updated_on)),
	}

	local content_width = 1
	for _, line in ipairs(lines) do
		content_width = math.max(content_width, vim.fn.strdisplaywidth(line))
	end
	lines[2] = " " .. ("━"):rep(content_width)

	local highlights = {
		{ row = 1, col = 0, end_col = -1, hl_group = "AtlasTextMuted" },
		{ row = 2, col = 1, end_col = 10, hl_group = "AtlasTextMuted" },
		{ row = 3, col = 1, end_col = 10, hl_group = "AtlasTextMuted" },
		{ row = 4, col = 1, end_col = 10, hl_group = "AtlasTextMuted" },
		{ row = 5, col = 1, end_col = 10, hl_group = "AtlasTextMuted" },
		{ row = 6, col = 1, end_col = 10, hl_group = "AtlasTextMuted" },
		{ row = 7, col = 1, end_col = 10, hl_group = "AtlasTextMuted" },
		{ row = 8, col = 1, end_col = 10, hl_group = "AtlasTextMuted" },
		{ row = 2, col = 11, end_col = -1, hl_group = helper.pr_state_hl(pr.state) },
		{ row = 3, col = 11, end_col = -1, hl_group = helper.author_hl(author_name) },
		{ row = 4, col = 11, end_col = -1, hl_group = helper.repo_hl(repo_name) },
		{ row = 5, col = 11, end_col = -1, hl_group = "AtlasTextMuted" },
		{ row = 8, col = 11, end_col = -1, hl_group = "AtlasTextMuted" },
	}

	if id ~= "" then
		table.insert(highlights, {
			row = 0,
			col = 2,
			end_col = 2 + #id,
			hl_group = "AtlasTextMuted",
		})
	end

	return lines, highlights
end

return M
