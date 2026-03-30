local M = {}

local icons = require("atlas.ui.icons")
local utils = require("atlas.utils")
local highlights = require("atlas.ui.highlights")

---@param row table
---@param col TableColumn
---@return string|nil
function M.cell_hl(row, col)
	if col.key == "pr_icon" then
		return "AtlasTextPositive"
	end

	if col.key == "branch" then
		return "AtlasTextMuted"
	end

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
---@param repos BitbucketRepoPRGroup[]|nil
---@param current_user BitbucketCurrentUser|nil
---@return table[]
function M.build_footer_items(repos, current_user)
	local groups = repos or {}
	local pr_count = 0
	local repo_names = {}
	local seen = {}

	for _, group in ipairs(groups) do
		pr_count = pr_count + #(group.pullrequests or {})
		local name = group.repo
		if name ~= nil and name ~= "" and not seen[name] then
			seen[name] = true
			table.insert(repo_names, name)
		end
	end

	local items = {
		{
			text = string.format("%s %d PR%s", icons.entity("pr"), pr_count, pr_count == 1 and "" or "s"),
			hl_group = "AtlasBitbucketTheme",
		},
	}

	local user_name = tostring((current_user or {}).nickname or (current_user or {}).display_name or "")
	if user_name ~= "" then
		table.insert(items, {
			text = string.format("%s @%s", icons.entity("author"), user_name),
			hl_group = "AtlasFooterText",
		})
	end

	for _, name in ipairs(repo_names) do
		table.insert(items, { text = string.format("%s %s", icons.entity("repo"), name), hl_group = "AtlasFooterText" })
	end

	return items
end

local function coloumns()
	return {
		{ key = "pr_icon", name = "", min_width = 1, can_grow = false, header_hl = "AtlasColumnHeader" },
		{ key = "repo_pr", name = "PR", min_width = 42, header_hl = "AtlasColumnHeader" },
		{ key = "comments", name = icons.entity("comments"), min_width = 2, can_grow = false, header_hl = "AtlasColumnHeader" },
		{ key = "tasks", name = icons.entity("tasks"), min_width = 2, can_grow = false, header_hl = "AtlasColumnHeader" },
		{ key = "author", name = "Author", min_width = 3, can_grow = false, header_hl = "AtlasColumnHeader" },
		{ key = "repo", name = "Repo", min_width = 5, can_grow = false, header_hl = "AtlasColumnHeader" },
		{ key = "created", name = icons.entity("created"), can_grow = false, header_hl = "AtlasColumnHeader" },
		{ key = "updated", name = icons.entity("updated"), can_grow = false, header_hl = "AtlasColumnHeader" },
	}
end

local function append_compact_group_rows(rows, group)
	for _, pr in ipairs(group.pullrequests or {}) do
		table.insert(rows, {
			kind = "pr",
			pr_icon = icons.entity("pr"),
			repo_pr = string.format("#%s %s", tostring(pr.id), pr.title or ""),
			comments = tostring(pr.comments),
			tasks = tostring(pr.tasks),
			author = pr.author.name,
			repo = group.full_name,
			created = utils.relative_time(pr.created_on),
			updated = utils.relative_time(pr.updated_on),
			_item = { kind = "pr", id = pr.id, repo = group.full_name, pr = pr },
		})

		table.insert(rows, {
			kind = "meta",
			pr_icon = "",
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
				pr = pr,
			},
		})
	end
end

local function append_plain_group_rows(rows, group)
	for _, pr in ipairs(group.pullrequests or {}) do
		table.insert(rows, {
			kind = "pr",
			pr_icon = icons.entity("pr"),
			repo_pr = string.format("#%s %s", tostring(pr.id), pr.title or ""),
			comments = tostring(pr.comments),
			tasks = tostring(pr.tasks),
			author = pr.author.name,
			repo = group.full_name,
			branch = string.format("%s -> %s", pr.source_branch or "?", pr.target_branch or "?"),
			created = utils.relative_time(pr.created_on),
			updated = utils.relative_time(pr.updated_on),
			_item = { kind = "pr", id = pr.id, repo = group.full_name, pr = pr },
		})
	end
end

---@param repo_groups BitbucketRepoPRGroup[]
---@return { rows: table[], columns: table[] }
function M.build_compact_table(repo_groups)
	local rows = {}
	for _, group in ipairs(repo_groups or {}) do
		append_compact_group_rows(rows, group)
	end
	return {
		rows = rows,
		columns = coloumns(),
	}
end

---@param repo_groups BitbucketRepoPRGroup[]
---@return { rows: table[], columns: table[] }
function M.build_plain_table(repo_groups)
	local rows = {}
	for _, group in ipairs(repo_groups or {}) do
		append_plain_group_rows(rows, group)
	end
	return {
		rows = rows,
		columns = coloumns(),
	}
end

return M
