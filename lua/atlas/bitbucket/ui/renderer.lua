local M = {}

local config = require("atlas.config")
local icons = require("atlas.ui.icons")
local state = require("atlas.bitbucket.state")
local header = require("atlas.ui.components.header")
local navbar = require("atlas.ui.components.navbar")
local table_view = require("atlas.ui.components.table")
local utils = require("atlas.utils")
local highlights = require("atlas.ui.highlights")
local spinner = require("atlas.ui.popups.spinner")
local service = require("atlas.bitbucket.api.service")

---@param row table
---@param col TableColumn
---@return string|nil
local function bitbucket_cell_hl(row, col)
	if col.key == "created" or col.key == "updated" or (row.kind == "meta" and col.key == "repo_pr") then
		return "AtlasTextMuted"
	end

	if col.key == "author" then
		return highlights.dynamic_for(row.author)
	end

	if col.key == "repo" then
		return highlights.dynamic_for(row.repo)
	end

	return nil
end

---@param rows table[]
---@param group BitbucketRepoPRGroup
local function append_plain_pr_rows(rows, group)
	for _, pr in ipairs(group.pullrequests or {}) do
		table.insert(rows, {
			kind = "pr",
			repo_pr = string.format("#%s %s", tostring(pr.id), pr.title or ""),
			comments = tostring(pr.comments),
			tasks = tostring(pr.tasks),
			author = pr.author.name,
			repo = group.full_name,
			created = utils.relative_time(pr.created_on),
			updated = utils.relative_time(pr.updated_on),
			_item = { kind = "pr", id = pr.id, repo = group.full_name },
		})

		table.insert(rows, {
			kind = "meta",
			repo_pr = string.format("%s → %s", pr.source_branch or "?", pr.target_branch or "?"),
			comments = "",
			tasks = "",
			author = "",
			repo = "",
			created = "",
			updated = "",
			separator = true,
			_item = {
				kind = "pr_meta",
				id = pr.id,
				repo = group.full_name,
				source_branch = pr.source_branch or "?",
				target_branch = pr.target_branch or "?",
			},
		})
	end
end

local function to_plain_rows(repo_groups)
	local rows = {}

	for _, group in ipairs(repo_groups or {}) do
		append_plain_pr_rows(rows, group)
	end

	return rows
end

local function table_columns()
	return {
		{ key = "repo_pr", name = "PR", min_width = 42, header_hl = "AtlasColumnHeader" },
		{ key = "comments", name = "󰅺", min_width = 2, can_grow = false, header_hl = "AtlasColumnHeader" },
		{ key = "tasks", name = "󰄱", min_width = 2, can_grow = false, header_hl = "AtlasColumnHeader" },
		{ key = "author", name = "Author", min_width = 3, can_grow = false, header_hl = "AtlasColumnHeader" },
		{ key = "repo", name = "Repo", min_width = 5, can_grow = false, header_hl = "AtlasColumnHeader" },
		{ key = "created", name = "󰃭", can_grow = false, header_hl = "AtlasColumnHeader" },
		{ key = "updated", name = "󰥔", can_grow = false, header_hl = "AtlasColumnHeader" },
	}
end

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
					hl_group = "AtlasLogInfo",
				})
			end
		end
	end
end

---@param opts { width: number, height: number }
---@param repos BitbucketRepoPRGroup[]
---@return string[]
---@return table[]
---@return table<number, table>
local function build_plain_content(opts, repos)
	local rows = to_plain_rows(repos)
	local tbl_lines, tbl_map, tbl_spans = table_view.render({
		width = opts.width,
		margin = 1,
		columns = table_columns(),
		rows = rows,
		cell_hl = bitbucket_cell_hl,
	})
	add_pr_id_spans(tbl_lines, tbl_map, tbl_spans)

	return tbl_lines, tbl_spans, tbl_map
end

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

		local rows = {}
		append_plain_pr_rows(rows, group)
		if #rows == 0 then
			table.insert(lines, "(no pull requests)")
		else
			local tbl_lines, tbl_map, tbl_spans = table_view.render({
				width = opts.width,
				margin = 1,
				columns = table_columns(),
				rows = rows,
				cell_hl = bitbucket_cell_hl,
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
		{ label = string.format(" %s Refresh (r) ", icons.entity("refresh")), hl_group = "AtlasBitbucketTheme" },
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

---@param a BitbucketViewConfig|nil
---@param b BitbucketViewConfig|nil
---@return boolean
local function same_view(a, b)
	if a == nil and b == nil then
		return true
	end

	if a == nil or b == nil then
		return false
	end

	local a_id = a.key or a.name or ""
	local b_id = b.key or b.name or ""
	return a_id == b_id
end

---@param view BitbucketViewConfig|nil
---@param opts { force_refresh: boolean }
---@param on_done fun()
local function ensure_loaded(view, opts, on_done)
	local is_current_view = same_view(view, state.current_view)
	if state.is_loading or state.repos ~= nil and is_current_view then
		return
	end

	state.is_loading = true
	state.error = nil

	service.fetch_pullrequests((view and view.repos) or {}, { force_load = opts.force_refresh }, function(groups, err)
		state.is_loading = false
		if err then
			state.error = tostring(err)
			state.repos = {}
		else
			state.repos = groups or {}
		end

		on_done()
	end)
end

---@param opts { width: number, height: number, force_refresh: boolean }
---@param rerender fun(view: "bitbucket"|"github"|"jira")
function M.render(opts, rerender)
	if opts.force_refresh then
		state.current_view = nil
	end

	local views = (config.options.bitbucket and config.options.bitbucket.views) or {}
	if state.active_view == nil and views[1] then
		state.active_view = views[1]
	end

	local lines, spans = {}, {}
	local line_map = {}

	render_header(lines, spans, opts.width, views)
	table.insert(lines, "")

	ensure_loaded(state.active_view, { force_refresh = opts.force_refresh }, function()
		spinner.stop()
		state.current_view = state.active_view
		rerender("bitbucket")
	end)

	if state.error then
		table.insert(lines, "Error loading pull requests: " .. state.error)
	elseif state.is_loading then
		spinner.start()
		table.insert(lines, "Loading...")
	else
		local grouped = state.active_view ~= nil and state.active_view.layout == "grouped"
		local body_lines, body_spans, body_map
		if grouped then
			body_lines, body_spans, body_map = build_grouped_content(opts, state.repos or {})
		else
			body_lines, body_spans, body_map = build_plain_content(opts, state.repos or {})
		end

		local body_base = #lines
		utils.append_block(lines, spans, { lines = body_lines, highlights = body_spans })
		for lnum, node in pairs(body_map) do
			line_map[body_base + lnum] = node
		end
	end

	return lines, spans, line_map
end

return M
