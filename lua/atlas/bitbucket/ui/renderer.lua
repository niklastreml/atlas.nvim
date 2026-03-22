local M = {}

local config = require("atlas.config")
local icons = require("atlas.ui.icons")
local state = require("atlas.bitbucket.state")
local header = require("atlas.ui.components.header")
local navbar = require("atlas.ui.components.navbar")
local table_view = require("atlas.ui.components.table")
local utils = require("atlas.utils")
local spinner = require("atlas.ui.popups.spinner")
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
			hl_group = "AtlasTitleBitbucket",
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
		{ label = string.format(" %s Refresh (r) ", icons.action("refresh")), hl_group = "AtlasTitleBitbucket" },
	}

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
end

---@param view BitbucketViewConfig|nil
---@param on_done fun()
local function ensure_loaded(view, on_done)
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

		on_done()
	end)
end

---@param opts { width: number, height: number }
---@param rerender fun(view: "bitbucket"|"github"|"jira")
function M.render(opts, rerender)
	local views = (config.options.bitbucket and config.options.bitbucket.views) or {}
	if state.active_view == nil and views[1] then
		state.active_view = views[1]
	end

	local lines, spans = {}, {}
	local line_map = {}

	render_header(lines, spans, opts.width, views)
	table.insert(lines, "")

	ensure_loaded(state.active_view, function()
		spinner.stop()
		rerender("bitbucket")
	end)

	if state.error then
		table.insert(lines, "Error loading pull requests: " .. state.error)
	elseif state.is_loading and state.repos == nil then
		spinner.start()
		table.insert(lines, "Loading...")
	else
		local rows = to_rows(state.repos or {})
		local tbl_lines, tbl_map, tbl_spans = table_view.render({
			width = opts.width,
			margin = 0,
			columns = {
				{ key = "id", name = "ID", min_width = 8, can_grow = false, header_hl = "Normal" },
				{ key = "repo_pr", name = "PR", min_width = 34, header_hl = "Normal" },
				{ key = "comments", name = "󰅺", min_width = 2, can_grow = false, header_hl = "Normal" },
				{ key = "tasks", name = "󰄱", min_width = 2, can_grow = false, header_hl = "Normal" },
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

	return lines, spans, line_map
end

return M
