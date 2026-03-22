local M = {}

local config = require("atlas.config")
local icons = require("atlas.ui.icons")
local state = require("atlas.bitbucket.state")
local header = require("atlas.ui.components.header")
local navbar = require("atlas.ui.components.navbar")
local footer = require("atlas.ui.components.footer")
local table_view = require("atlas.ui.components.table")
local utils = require("atlas.utils")
local service = require("atlas.bitbucket.api.service")

local function to_rows(repo_groups)
	local rows = {}

	for _, group in ipairs(repo_groups or {}) do
		for _, pr in ipairs(group.pullrequests or {}) do
			table.insert(rows, {
				kind = "pr",
				id = "#" .. tostring(pr.id),
				repo_pr = pr.title,
				comments = tostring(pr.comments),
				tasks = tostring(pr.tasks),
				author = pr.author.name,
				repo = group.full_name,
				updated = utils.relative_time(pr.updated_on),
				_item = { kind = "pr", id = pr.id, repo = group.full_name },
			})

			table.insert(rows, {
				kind = "meta",
				id = "",
				repo_pr = string.format("%s → %s", pr.source_branch or "?", pr.target_branch or "?"),
				comments = "",
				tasks = "",
				author = "",
				repo = "",
				updated = "",
				separator = true,
				_item = { kind = "pr_meta", id = pr.id, repo = group.full_name },
			})
		end
	end

	return rows
end

local function ensure_loaded(view)
	if state.is_loading or state.repos ~= nil then
		return
	end

	state.is_loading = true
	state.error = nil

	service.fetch_pullrequests((view and view.repos) or {}, function(groups, err)
		state.is_loading = false
		if err then
			state.error = tostring(err)
			state.repos = {}
		else
			state.repos = groups or {}
		end

		--- TODO: Dont call renderer directly. Use callback in the render function to trigger re-render when data is loaded
		require("atlas.ui.renderer").render("bitbucket")
	end)
end

function M.render(width, height)
	local views = (config.options.bitbucket and config.options.bitbucket.views) or {}
	if state.active_view == nil and views[1] then
		state.active_view = views[1]
	end

	--- NavBar ---
	local nav_items = {}
	for _, v in ipairs(views) do
		local key = v.key or v.name
		local label = v.key and string.format("%s (%s)", v.name, v.key) or v.name
		table.insert(nav_items, {
			label = label,
			active = key == state.active_view.key,
		})
	end

	local actions = {
		{ label = string.format(" %s Refresh (r) ", icons.action("refresh")), hl_group = "AtlasTitleBitbucket" },
	}

	local lines, spans = {}, {}
	local line_map = {}

	utils.append_block(
		lines,
		spans,
		header.render({
			width = width,
			icon = icons.provider("bitbucket"),
			title = "Bitbucket",
			hl_group = "AtlasTitleBitbucket",
		})
	)

	utils.append_block(
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

	ensure_loaded(state.active_view)
	if state.error then
		table.insert(lines, "Error loading pull requests: " .. state.error)
	elseif state.is_loading and state.repos == nil then
		table.insert(lines, "Loading...")
	else
		local rows = to_rows(state.repos or {})
		local tbl_lines, tbl_map, tbl_spans = table_view.render({
			width = width,
			margin = 0,
			columns = {
				{ key = "id", name = "ID", min_width = 8, can_grow = false, header_hl = "Normal" },
				{ key = "repo_pr", name = "PR", min_width = 34, header_hl = "Normal" },
				{ key = "comments", name = "󰅺", min_width = 2, can_grow = false, header_hl = "Normal" },
				{ key = "tasks", name = "☐", min_width = 2, can_grow = false, header_hl = "Normal" },
				{ key = "author", name = "Author", min_width = 3, can_grow = false, header_hl = "Normal" },
				{ key = "repo", name = "Repo", min_width = 5, can_grow = false, header_hl = "Normal" },
				{ key = "updated", name = "󰥔", min_width = 4, can_grow = false, header_hl = "Normal" },
			},
			rows = rows,
		})

		local table_base = #lines
		utils.append_block(lines, spans, { lines = tbl_lines, highlights = tbl_spans })
		for lnum, node in pairs(tbl_map) do
			line_map[table_base + lnum] = node
		end
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

	utils.append_block(lines, spans, footer_block)
	return lines, spans, line_map
end

return M
