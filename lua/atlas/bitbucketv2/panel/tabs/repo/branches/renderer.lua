local M = {}

local tab_state = require("atlas.bitbucketv2.panel.tabs.repo.branches.state")
local state = require("atlas.bitbucketv2.panel.tabs.repo.state")
local panel_state = require("atlas.bitbucketv2.panel.state")
local header = require("atlas.bitbucketv2.panel.components.header")
local chips = require("atlas.bitbucketv2.panel.components.chips")
local tabs_component = require("atlas.bitbucketv2.panel.components.tabs")
local utils = require("atlas.utils")
local spinner = require("atlas.ui.components.spinner")
local icons = require("atlas.ui.icons")
local table_view = require("atlas.ui.components.table")
local highlights = require("atlas.ui.highlights")

---@param width integer
---@return string[] lines
---@return table[] spans
---@return table|nil line_map
function M.render(width)
	local lines = {}
	local spans = {}
	local line_map = {}

	local repo = tab_state.repo
	local detail = state.detail
	local branches = tab_state.branches

	if repo == nil then
		return { "", "  No repository selected..." }, {}, nil
	end

	-- Header
	if detail ~= nil and detail ~= "loading" then
		local header_lines, header_spans = header.render_repo(repo, detail, width)
		for _, line in ipairs(header_lines) do
			table.insert(lines, line)
		end
		for _, span in ipairs(header_spans) do
			table.insert(spans, span)
		end

		-- Chips
		local chip_line, chip_spans = chips.render_repo(detail)
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
	else
		local loading_line = spinner.with_text("Loading repository...")
		table.insert(lines, loading_line)
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #loading_line,
			hl_group = "AtlasTextMuted",
		})
		table.insert(lines, "")
	end

	-- Tabs
	local tab_lines, tab_spans = tabs_component.render_repo(panel_state.current_tab, width, 0)
	local tab_base = #lines
	for _, line in ipairs(tab_lines) do
		table.insert(lines, line)
	end
	for _, span in ipairs(tab_spans) do
		table.insert(spans, {
			line = tab_base + span.line,
			start_col = span.start_col,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end
	table.insert(lines, "")

	-- Branches content
	if branches == "loading" then
		local loading_line = spinner.with_text("Loading branches...")
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

	if branches == nil or branches.entries == nil or #branches.entries == 0 then
		table.insert(lines, "No branches found.")
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #lines[#lines],
			hl_group = "AtlasTextMuted",
		})
		state.line_map = line_map
		return lines, spans, line_map
	end

	-- Build table rows
	local rows = {}
	for _, b in ipairs(branches.entries) do
		local msg = tostring(b.message or ""):gsub("\r\n", "\n")
		msg = msg:match("([^\n]+)") or msg
		table.insert(rows, {
			branch = tostring(b.name or "-"),
			message = msg,
			author = tostring(b.author or "-"),
			timestamp = utils.relative_time(tostring(b.date or "")),
		})
	end

	local table_lines, _, table_spans = table_view.render({
		width = width,
		margin = 0,
		column_gap = 1,
		show_header = true,
		fill = true,
		columns = {
			{ key = "branch", name = icons.entity("branch"), can_grow = false },
			{ key = "message", name = "Message", min_width = 24, can_grow = true },
			{ key = "author", name = "Author", can_grow = false },
			{ key = "timestamp", name = icons.entity("updated"), can_grow = false },
		},
		rows = rows,
		cell_hl = function(row, col)
			if col.key == "message" then
				return "AtlasTextMuted"
			end
			if col.key == "timestamp" then
				return "AtlasTextMuted"
			end
			if col.key == "author" then
				return highlights.dynamic_for(row.author)
			end
			return nil
		end,
	})

	local table_base = #lines
	for _, line in ipairs(table_lines) do
		table.insert(lines, line)
	end
	for _, span in ipairs(table_spans) do
		table.insert(spans, {
			line = table_base + span.line,
			start_col = span.start_col,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end

	tab_state.line_map = line_map
	return lines, spans, line_map
end

return M
