local M = {}

local state = require("atlas.bitbucket.panel.tabs.pr.commits.state")
local panel_state = require("atlas.bitbucket.panel.state")
local header = require("atlas.bitbucket.panel.components.header")
local chips = require("atlas.bitbucket.panel.components.chips")
local tabs_component = require("atlas.bitbucket.panel.components.tabs")
local utils = require("atlas.utils")
local icons = require("atlas.ui.icons")
local table_view = require("atlas.ui.components.table_tree")
local spinner = require("atlas.ui.components.spinner")
local highlights = require("atlas.ui.highlights")

---@param width integer
---@return string[] lines
---@return table[] spans
---@return table|nil line_map
function M.render(width)
	local lines = {}
	local spans = {}
	local line_map = {}

	local pr = state.pr
	local commits = state.commits

	if pr == nil then
		return { "", "  No PR selected..." }, {}, nil
	end

	-- Header
	local header_lines, header_spans = header.render(pr, width)
	utils.append_block(lines, spans, { lines = header_lines, highlights = header_spans })

	-- Chips
	local chip_line, chip_spans = chips.render(pr)
	table.insert(lines, chip_line)
	local chip_base = #lines - 1
	for _, span in ipairs(chip_spans) do
		table.insert(spans, {
			line = chip_base,
			start_col = span.start_col,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end
	table.insert(lines, "")

	-- Tabs
	local tab_lines, tab_spans = tabs_component.render_pr(panel_state.current_tab, { width = width, padding_x = 1 })
	utils.append_block(lines, spans, { lines = tab_lines, highlights = tab_spans })
	table.insert(lines, "")

	-- Commits content
	if commits == "loading" then
		local loading_line = spinner.with_text("Loading commits...")
		table.insert(lines, loading_line)
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #loading_line,
			hl_group = "AtlasTextMuted",
		})
		state.line_map = line_map
		return lines, spans, line_map
	end

	local entries = (commits ~= nil and commits.entries) or {}
	if #entries == 0 then
		table.insert(lines, "No commits yet.")
		state.line_map = line_map
		return lines, spans, line_map
	end

	local rows = {}
	for _, c in ipairs(entries) do
		local msg = tostring(c.message or ""):gsub("\r\n", "\n")
		msg = msg:match("([^\n]+)") or msg
		local author = (c.author_nickname ~= "" and c.author_nickname) or c.author_name or "Unknown"
		local hash = tostring(c.short_hash or c.hash or "")
		hash = hash:sub(1, 8)
		table.insert(rows, {
			icon = icons.entity("commit"),
			hash = hash,
			message = msg,
			author = author,
			date = utils.relative_time(c.date),
		})
	end

	local table_lines, _, table_spans = table_view.render({
		width = width,
		margin = 0,
		column_gap = 1,
		show_header = false,
		fill = true,
		columns = {
			{ key = "icon", name = "", width = 2, can_grow = false },
			{ key = "hash", name = "", width = 12, can_grow = false },
			{ key = "message", name = "", min_width = 24, can_grow = true },
			{ key = "author", name = "", can_grow = false },
			{ key = "date", name = "", width = 6, can_grow = false },
		},
		rows = rows,
		cell_hl = function(row, col)
			if col.key == "icon" then
				return "AtlasTextPositive"
			end
			if col.key == "hash" or col.key == "date" then
				return "AtlasTextMuted"
			end
			if col.key == "author" then
				return highlights.dynamic_for(row.author)
			end
			return nil
		end,
	})

	utils.append_block(lines, spans, { lines = table_lines, highlights = table_spans })

	state.line_map = line_map
	return lines, spans, line_map
end

return M
