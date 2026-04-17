local M = {}

local icons = require("atlas.ui.shared.icons")
local highlights = require("atlas.ui.shared.highlights")
local table_tree = require("atlas.ui.components.table_tree")
local utils = require("atlas.ui.shared.utils")
local helper = require("atlas.pulls.ui.main.helper")

---@param spans table[]
---@param lines string[]
---@param line integer
---@param start_col integer
---@param end_col integer
---@param hl_group string
local function add_span(spans, lines, line, start_col, end_col, hl_group)
	local text = lines[line + 1] or ""
	local max_col = #text
	local s = math.max(0, math.min(start_col, max_col))
	local e = math.max(s, math.min(end_col, max_col))
	if e <= s then
		return
	end
	table.insert(spans, {
		line = line,
		start_col = s,
		end_col = e,
		hl_group = hl_group,
	})
end

---@param pr PullRequest
---@param width integer
---@param extra_rows PullsPanelHeaderRow[]|nil
---@return string[], table[]
function M.render(pr, width, extra_rows)
	local author_name = (pr.author and pr.author.name) or "Unknown"
	local created_text = utils.relative_time_text(pr.created_on)
	local repo_name = tostring(pr.repo_name or "")
	local src = tostring((pr.source or {}).branch or "?")
	local dst = tostring((pr.destination or {}).branch or "?")

	local id_text = string.format("#%s", tostring(pr.id or "?"))
	local title_text = tostring(pr.title or "")
	local title = string.format(" %s %s", id_text, title_text)

	local author_icon = icons.general("user")
	local by_prefix = string.format(" %s by @", author_icon)
	local by_sep = " - "
	local byline = by_prefix .. author_name .. by_sep .. created_text

	local lines = {
		title,
		byline,
		"",
	}

	local updated_text = utils.relative_time_text(pr.updated_on)

	local rows = {
		{
			k1 = "Repo:",
			v1 = string.format("%s %s", icons.pulls("repo"), repo_name),
			v1_hl = highlights.dynamic_for(repo_name) or "AtlasTextMuted",
			k2 = "Branch:",
			v2 = string.format("%s %s → %s", icons.pulls("branch"), src, dst),
			v2_hl = "AtlasTextMuted",
		},
		{
			k1 = "Updated:",
			v1 = updated_text,
			v1_hl = "AtlasTextMuted",
			k2 = "",
			v2 = "",
			v2_hl = "AtlasTextMuted",
		},
	}

	for _, row in ipairs(extra_rows or {}) do
		table.insert(rows, row)
	end

	local tbl_lines, _, tbl_spans = table_tree.render({
		width = width,
		margin = 1,
		show_header = false,
		column_gap = 1,
		fill = true,
		columns = {
			{ key = "k1", name = "", can_grow = false },
			{ key = "v1", name = "", can_grow = true },
			{ key = "k2", name = "", can_grow = false },
			{ key = "v2", name = "", can_grow = true, grow_last = true },
		},
		rows = rows,
		cell_hl = function(row, col, ctx)
			if col.key == "k1" or col.key == "k2" then
				local label = col.key == "k1" and row.k1 or row.k2
				return { { start_col = 0, end_col = #label, hl_group = "AtlasTextMuted" } }
			end
			if col.key == "v1" then
				return { { start_col = 0, end_col = #row.v1, hl_group = row.v1_hl } }
			end
			if col.key == "v2" then
				return { { start_col = 0, end_col = #row.v2, hl_group = row.v2_hl } }
			end
			return nil
		end,
	})

	for _, l in ipairs(tbl_lines) do
		table.insert(lines, l)
	end
	table.insert(lines, "")

	-- Spans
	local spans = {
		{ line = 0, line_hl_group = "AtlasPanelHeaderBg" },
		{ line = 1, line_hl_group = "AtlasPanelHeaderBg" },
	}

	add_span(spans, lines, 0, 1, 1 + #id_text, "AtlasTextMuted")

	local author_start = #by_prefix - 1
	local author_end = author_start + #("@" .. author_name)
	add_span(spans, lines, 1, author_start, author_end, helper.author_hl(author_name))

	local ts_start = author_end + #by_sep
	local ts_end = ts_start + #created_text
	add_span(spans, lines, 1, ts_start, ts_end, "AtlasTextMuted")

	for _, span in ipairs(tbl_spans) do
		table.insert(spans, {
			line = span.line + 3,
			start_col = span.start_col,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end

	return lines, spans
end

return M
