local M = {}

local icons = require("atlas.ui.icons")
local utils = require("atlas.utils")
local highlights = require("atlas.ui.highlights")

---@param pr table
---@return string[] lines
---@return table[] spans
function M.render(pr)
	local author = (pr.author and pr.author.nickname) or (pr.author and pr.author.name) or "unknown"
	local timestamp = (pr.created_on and pr.created_on ~= "") and pr.created_on
	local repo = (pr.repo or {}).name or "-"
	local pr_icon = icons.entity("pr")
	local repo_icon = icons.entity("repo")
	local source_icon = icons.entity("branch")
	local author_icon = icons.entity("author")

	local title = string.format("%s #%s • %s", pr_icon, tostring(pr.id or "?"), tostring(pr.title or ""))
	local byline = string.format("%s by @%s - %s", author_icon, author, utils.relative_time_text(timestamp))
	local repo_line = string.format("%s %s", repo_icon, repo)
	local source_line =
		string.format("%s %s -> %s", source_icon, tostring(pr.source_branch or "-"), tostring(pr.target_branch or "-"))

	local lines = {
		title,
		byline,
		"",
		repo_line,
		source_line,
	}

	local id_prefix = string.format("%s #%s • ", pr_icon, tostring(pr.id or "?"))
	local repo_prefix = string.format("%s ", repo_icon)
	local source_prefix = string.format("%s ", source_icon)
	local repo_icon_hl = highlights.dynamic_for(repo) or "AtlasTextPositive"
	local spans = {
		{ line = 0, line_hl_group = "AtlasTabInactive" },
		{ line = 1, line_hl_group = "AtlasTabInactive" },
		{ line = 0, start_col = 0, end_col = #pr_icon, hl_group = "AtlasBitbucketTheme" },
		{ line = 1, start_col = 0, end_col = #author_icon, hl_group = "AtlasTextWarning" },
		{ line = 3, start_col = 0, end_col = #repo_icon, hl_group = repo_icon_hl },
		{ line = 4, start_col = 0, end_col = #source_icon, hl_group = "AtlasTextPositive" },
		{ line = 0, start_col = #id_prefix, end_col = #title, hl_group = "AtlasTextMuted" },
		{ line = 3, start_col = #repo_prefix, end_col = #repo_line, hl_group = "AtlasTextMuted" },
		{ line = 4, start_col = #source_prefix, end_col = #source_line, hl_group = "AtlasTextMuted" },
	}

	return lines, spans
end

return M
