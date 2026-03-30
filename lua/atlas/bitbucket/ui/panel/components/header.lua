local M = {}

local icons = require("atlas.ui.icons")
local utils = require("atlas.utils")
local highlights = require("atlas.ui.highlights")
local table_view = require("atlas.ui.components.table")

---@param pr table
---@param width integer|nil
---@return string[] lines
---@return table[] spans
function M.render(pr, width)
	local author = (pr.author and pr.author.nickname) or (pr.author and pr.author.name) or "unknown"
	local timestamp = (pr.created_on and pr.created_on ~= "") and pr.created_on or ""
	local repo = (pr.repo or {}).name or "-"
	local pr_icon = icons.entity("pr")
	local repo_icon = icons.entity("repo")
	local source_icon = icons.entity("branch")
	local author_icon = icons.entity("author")
	local close_icon = (pr.close_source_branch and icons.entity("success")) or icons.entity("pending")

	local title = string.format("%s #%s • %s", pr_icon, tostring(pr.id or "?"), tostring(pr.title or ""))
	local byline = string.format("%s by @%s - %s", author_icon, author, utils.relative_time_text(timestamp))
	local repo_icon_hl = highlights.dynamic_for(repo) or "AtlasTextPositive"
	local close_line = string.format("close source %s", (pr.close_source_branch and "yes") or "no")

	local lines = {
		title,
		byline,
		"",
	}

	local rows = {
		{ icon = repo_icon, text = repo, icon_hl = repo_icon_hl },
		{
			icon = source_icon,
			text = string.format("%s -> %s", tostring(pr.source_branch or "-"), tostring(pr.target_branch or "-")),
			icon_hl = "AtlasTextPositive",
		},
		{
			icon = close_icon,
			text = close_line,
			icon_hl = (pr.close_source_branch and "AtlasTextPositive") or "AtlasTextMuted",
		},
	}

	local table_lines, _, table_spans = table_view.render({
		width = width or 60,
		margin = 0,
		column_gap = 1,
		show_header = false,
		fill = false,
		columns = {
			{ key = "icon", name = "", width = 2, can_grow = false },
			{ key = "text", name = "", min_width = 20, can_grow = false },
		},
		rows = rows,
		cell_hl = function(row, col)
			if col.key == "icon" then
				return row.icon_hl
			end
			if col.key == "text" then
				return "AtlasTextMuted"
			end
			return nil
		end,
	})

	local table_base = #lines
	for _, line in ipairs(table_lines) do
		table.insert(lines, line)
	end

	local id_prefix = string.format("%s #%s • ", pr_icon, tostring(pr.id or "?"))
	local spans = {
		{ line = 0, line_hl_group = "AtlasTabInactive" },
		{ line = 1, line_hl_group = "AtlasTabInactive" },
		{ line = 0, start_col = 0, end_col = #pr_icon, hl_group = "AtlasBitbucketTheme" },
		{ line = 1, start_col = 0, end_col = #author_icon, hl_group = "AtlasTextWarning" },
		{ line = 0, start_col = #id_prefix, end_col = #title, hl_group = "AtlasTextMuted" },
	}

	for _, span in ipairs(table_spans or {}) do
		table.insert(spans, {
			line = table_base + span.line,
			start_col = span.start_col,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end

	return lines, spans
end

---@param repo table
---@param detail BitbucketRepositoryDetail
---@param width integer|nil
---@return string[] lines
---@return table[] spans
function M.render_repo(repo, detail, width)
	local repo_icon = icons.entity("repo")
	local created_icon = icons.entity("created")
	local updated_icon = icons.entity("updated")

	local full_name = tostring(repo.full_name or repo.repo or "Repository")
	local title = string.format("%s %s", repo_icon, full_name)

	local is_private = detail.is_private == true
	local updated_on = tostring(detail.updated_on or "")
	local byline = string.format(
		"%s %s - %s",
		icons.entity("author"),
		is_private and "private" or "public",
		utils.relative_time_text(updated_on)
	)

	local created_on = "-"
	created_on = utils.relative_time_text(tostring(detail.created_on or ""))

	local lines = {
		title,
		byline,
		"",
	}

	local rows = {
		{ icon = created_icon, text = string.format("created %s", created_on), icon_hl = "AtlasTextMuted" },
		{
			icon = updated_icon,
			text = string.format("updated %s", utils.relative_time_text(updated_on)),
			icon_hl = "AtlasTextMuted",
		},
	}

	local table_lines, _, table_spans = table_view.render({
		width = width or 60,
		margin = 0,
		column_gap = 1,
		show_header = false,
		fill = false,
		columns = {
			{ key = "icon", name = "", width = 2, can_grow = false },
			{ key = "text", name = "", min_width = 20, can_grow = false },
		},
		rows = rows,
		cell_hl = function(row, col)
			if col.key == "icon" then
				return row.icon_hl
			end
			if col.key == "text" then
				return "AtlasTextMuted"
			end
			return nil
		end,
	})

	local table_base = #lines
	for _, line in ipairs(table_lines) do
		table.insert(lines, line)
	end

	local spans = {
		{ line = 0, line_hl_group = "AtlasTabInactive" },
		{ line = 1, line_hl_group = "AtlasTabInactive" },
		{
			line = 0,
			start_col = 0,
			end_col = #repo_icon,
			hl_group = highlights.dynamic_for(full_name) or "AtlasBitbucketTheme",
		},
		{ line = 1, start_col = 0, end_col = #icons.entity("author"), hl_group = "AtlasTextWarning" },
	}

	for _, span in ipairs(table_spans or {}) do
		table.insert(spans, {
			line = table_base + span.line,
			start_col = span.start_col,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end

	return lines, spans
end

return M
