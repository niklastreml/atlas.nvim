local M = {}

local resolver = require("atlas.core.keymaps")
local state = require("atlas.pulls.state")
local helper = require("atlas.pulls.ui.main.helper")
local header = require("atlas.ui.components.header")
local navbar = require("atlas.ui.components.navbar")
local table_tree = require("atlas.ui.components.table_tree")
local utils = require("atlas.shared.utils")
local footer = require("atlas.ui.components.footer")

---@param table_lines string[]
---@param table_map table<integer, table>
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

---@return string
local function refresh_key_display()
	local keys = resolver.resolve("pulls.refresh_view")
	if type(keys) == "table" and #keys > 0 then
		return tostring(keys[1])
	end
	return "R"
end

---@param opts { width: integer }
---@param repos PullsGroup[]
---@return string[], table[], table<integer, table>
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

---@param opts { width: integer }
---@param repos PullsGroup[]
---@return string[], table[], table<integer, table>
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
---@param width integer
local function render_header(lines, spans, width)
	---@param v PullsView|nil
	---@return string
	local function view_id_str(v)
		if v == nil then
			return ""
		end
		return tostring(v.key or v.name or "")
	end

	local icon = state.provider and state.provider.icon or "•"
	local title = state.provider and state.provider.name or "Atlas"
	local hl_group = state.provider and state.provider.hl_group or "Title"

	utils.append_block(lines, spans, header.render({
		width = width,
		icon = icon,
		title = title,
		hl_group = hl_group,
	}))

	local views = state.provider and state.provider.views and state.provider.views() or {}
	local nav_source = {}
	for _, v in ipairs(views or {}) do
		table.insert(nav_source, v)
	end

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
		{
			label = string.format("Refresh (%s)", refresh_key_display()),
			hl_group = "AtlasTextMuted",
		},
	}

	utils.append_block(lines, spans, navbar.render({
		width = width,
		items = nav_items,
		actions = actions,
		active_hl = state.provider and state.provider.hl_group or "Title",
	}))
end

---@param opts { width: integer, height: integer }
---@return string[] lines, table[] spans, table<integer, table> line_map
function M.render(opts)
	local lines, spans = {}, {}
	local line_map = {}

	render_header(lines, spans, opts.width)
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
			body_lines, body_spans, body_map = build_plain_singleline_content(opts, state.pulls or {})
		else
			body_lines, body_spans, body_map = build_plain_content(opts, state.pulls or {})
		end

		local body_base = #lines
		utils.append_block(lines, spans, { lines = body_lines, highlights = body_spans })
		for lnum, node in pairs(body_map) do
			line_map[body_base + lnum] = node
		end

		footer.set_items(helper.build_footer_items(state.pulls, state.current_user))
	end

	return lines, spans, line_map
end

return M
