local M = {}

local icons = require("atlas.ui.icons")
local table_tree_v2 = require("atlas.ui.components.table_tree_v2")
local utils = require("atlas.utils")
local helper = require("atlas.bitbucket.ui.helper")

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

---@param pr BitbucketPR
---@param width integer|nil
---@return string[] lines
---@return table[] spans
function M.render(pr, width)
	local author_display = (pr.author and pr.author.nickname) or (pr.author and pr.author.name) or "unknown"
	local author_name_for_hl = (pr.author and pr.author.name) or author_display
	local timestamp = (pr.created_on and pr.created_on ~= "") and pr.created_on or ""
	local timestamp_text = utils.relative_time_text(timestamp)
	local updated_text = utils.relative_time_text(tostring(pr.updated_on or timestamp or ""))
	local workspace = tostring(pr.workspace or "")
	local repo_slug = tostring(pr.repo or "")
	local repo_name = (workspace ~= "" and repo_slug ~= "") and (workspace .. "/" .. repo_slug)
		or (repo_slug ~= "" and repo_slug or "-")
	local source_branch = tostring((pr.source or {}).branch or "-")
	local target_branch = tostring((pr.destination or {}).branch or "-")
	local close_source = pr.close_source_branch == true
	local branch_icon = icons.entity("branch")
	local repo_icon = icons.entity("repo")
	local author_icon = icons.entity("author")
	local id_text = string.format("#%s", tostring(pr.id or "?"))
	local title_text = tostring(pr.title or "")
	local title = string.format(" %s %s", id_text, title_text)

	local by_prefix = string.format("%s by @", author_icon)
	local by_sep = " - "
	local byline = by_prefix .. author_display .. by_sep .. timestamp_text

	local lines = {
		title,
		byline,
		"",
	}

	local rows = {
		{
			k1 = "Branch:",
			v1 = string.format("%s %s -> %s", branch_icon, source_branch, target_branch),
			v1_hl = "AtlasTextPositive",
			k2 = "Repo:",
			v2 = string.format("%s %s", repo_icon, repo_name),
			v2_hl = helper.repo_hl(repo_name),
		},
		{
			k1 = "Close source:",
			v1 = close_source and "yes" or "no",
			v1_hl = close_source and "AtlasTextPositive" or "AtlasLogError",
			k2 = "Updated:",
			v2 = updated_text,
			v2_hl = "AtlasTextMuted",
		},
	}

	local table_lines, _, table_spans = table_tree_v2.render({
		columns = {
			{ key = "k1", name = "", can_grow = false },
			{ key = "v1", name = "", can_grow = true },
			{ key = "k2", name = "", can_grow = false },
			{ key = "v2", name = "", can_grow = true, grow_last = true },
		},
		rows = rows,
		width = width or 60,
		margin = 1,
		show_header = false,
		column_gap = 2,
		fill = true,
		cell_hl = function(row, col)
			if col.key == "k1" or col.key == "k2" then
				local label = col.key == "k1" and row.k1 or row.k2
				return {
					{ start_col = 0, end_col = #label, hl_group = "AtlasTextMuted" },
				}
			end

			if col.key == "v1" then
				return {
					{ start_col = 0, end_col = #row.v1, hl_group = row.v1_hl },
				}
			end

			if col.key == "v2" then
				return {
					{ start_col = 0, end_col = #row.v2, hl_group = row.v2_hl },
				}
			end

			return nil
		end,
	})

	for _, l in ipairs(table_lines) do
		table.insert(lines, l)
	end
	table.insert(lines, "")

	local author_hl = helper.author_hl(author_name_for_hl)
	local spans = {
		{ line = 0, line_hl_group = "AtlasPanelHeaderBg" },
		{ line = 1, line_hl_group = "AtlasPanelHeaderBg" },
	}

	local id_start = 1
	local id_end = id_start + #id_text
	add_span(spans, lines, 0, id_start, id_end, "AtlasTextMuted")

	local author_start = #by_prefix - 1
	local author_end = author_start + #("@" .. author_display)
	add_span(spans, lines, 1, author_start, author_end, author_hl)

	local ts_start = author_end + #by_sep
	local ts_end = ts_start + #timestamp_text
	add_span(spans, lines, 1, ts_start, ts_end, "AtlasTextMuted")

	for _, span in ipairs(table_spans) do
		table.insert(spans, {
			line = span.line + 3,
			start_col = span.start_col,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end

	return lines, spans
end

---@param repo { workspace:string|nil, full_name:string|nil, readme:string|nil }
---@param detail BitbucketRepository
---@param width integer|nil
---@return string[] lines
---@return table[] spans
function M.render_repo(repo, detail, width)
	local full_name = tostring(repo.full_name or "Repository")
	local title = " " .. full_name
	local workspace = tostring(repo.workspace or "unknown")
	local timestamp_text = utils.relative_time_text(tostring(detail.created_on or ""))
	local by_prefix = string.format("%s by @", icons.entity("author"))
	local by_sep = " - "
	local byline = by_prefix .. workspace .. by_sep .. timestamp_text

	local lines = {
		title,
		byline,
		"",
	}

	local repo_hl = helper.repo_hl(full_name)
	local owner_hl = helper.author_hl(workspace)
	local spans = {
		{ line = 0, line_hl_group = "AtlasPanelHeaderBg" },
		{ line = 1, line_hl_group = "AtlasPanelHeaderBg" },
	}

	add_span(spans, lines, 0, 1, 1 + #full_name, repo_hl)

	local owner_start = #by_prefix - 1
	local owner_end = owner_start + #("@" .. workspace)
	add_span(spans, lines, 1, owner_start, owner_end, owner_hl)

	local ts_start = owner_end + #by_sep
	local ts_end = ts_start + #timestamp_text
	add_span(spans, lines, 1, ts_start, ts_end, "AtlasTextMuted")

	return lines, spans
end

return M
