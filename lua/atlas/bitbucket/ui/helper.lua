local M = {}

local icons = require("atlas.ui.icons")
local utils = require("atlas.utils")
local highlights = require("atlas.ui.highlights")

---@param name string|nil
---@return string
function M.author_hl(name)
	if type(name) ~= "string" then
		return "AtlasTextMutedItalic"
	end

	local lower = vim.trim(name):lower()
	if lower == "" or lower == "unknown" or lower == "none" then
		return "AtlasTextMutedItalic"
	end

	return highlights.dynamic_for(lower) or "AtlasTextMuted"
end

---@param repo string|nil
---@return string
function M.repo_hl(repo)
	if type(repo) ~= "string" then
		return "AtlasTextMutedItalic"
	end

	local lower = vim.trim(repo):lower()
	if lower == "" or lower == "none" then
		return "AtlasTextMutedItalic"
	end

	return highlights.dynamic_for(lower) or "AtlasTextMuted"
end

---@param state string|nil
---@return string
function M.pr_state_hl(state)
	local lower = tostring(state or ""):lower()
	if lower == "open" then
		return "AtlasBitbucketPROpen"
	end
	if lower == "merged" then
		return "AtlasBitbucketPRMerged"
	end
	if lower == "declined" or lower == "superseded" then
		return "AtlasBitbucketPRDeclined"
	end
	if lower == "draft" then
		return "AtlasBitbucketPRDraft"
	end
	return "AtlasTextMuted"
end

---@param prs BitbucketPR[]|nil
---@return BitbucketPRViewGroup[]
function M.group_prs_by_repo(prs)
	local source = prs or {}
	local grouped = {}
	local order = {}

	for _, pr in ipairs(source) do
		local workspace = tostring(pr.workspace or "")
		local repo = tostring(pr.repo or "")
		local key = workspace .. "/" .. repo
		if grouped[key] == nil then
			grouped[key] = {
				workspace = workspace,
				repo = repo,
				prs = {},
			}
			table.insert(order, key)
		end
		table.insert(grouped[key].prs, pr)
	end

	local out = {}
	for _, key in ipairs(order) do
		table.insert(out, grouped[key])
	end

	return out
end

---@param view BitbucketViewConfig|nil
---@return string
function M.view_id(view)
	if view == nil then
		return "default"
	end
	return view.key or view.name or "default"
end

---@param a BitbucketViewConfig|nil
---@param b BitbucketViewConfig|nil
---@return boolean
function M.same_view(a, b)
	if a == nil and b == nil then
		return true
	end
	if a == nil or b == nil then
		return false
	end
	return M.view_id(a) == M.view_id(b)
end

---@param row table
---@param col TableColumn
---@param ctx { text: string, padded: string, width: integer }
---@return table[]|nil
function M.cell_hl(row, col, ctx)
	if col.key == "name" and row.kind == "repo" then
		local hl_group = highlights.dynamic_for(row.repo_name)
		return {
			{ start_col = 0, end_col = #ctx.padded, hl_group = hl_group },
		}
	end

	if col.key == "pr_icon" then
		local hl_group = row.kind == "pr" and "AtlasTextPositive" or "AtlasTextMuted"
		return {
			{ start_col = 0, end_col = #ctx.padded, hl_group = hl_group },
		}
	end

	if col.key == "branch" then
		return {
			{ start_col = 0, end_col = #ctx.padded, hl_group = "AtlasTextMuted" },
		}
	end

	if col.key == "created" or col.key == "updated" or (row.kind == "meta" and col.key == "repo_pr") then
		return {
			{ start_col = 0, end_col = #ctx.padded, hl_group = "AtlasTextMuted" },
		}
	end

	if col.key == "author" then
		local hl_group = M.author_hl(row.author_hl or row.author)
		return {
			{ start_col = 0, end_col = #ctx.padded, hl_group = hl_group },
		}
	end

	if col.key == "repo" then
		local hl_group = M.repo_hl(row.repo_hl or row.repo)
		return {
			{ start_col = 0, end_col = #ctx.padded, hl_group = hl_group },
		}
	end

	return nil
end

---@param repos BitbucketPRViewGroup[]|nil
---@param current_user BitbucketCurrentUser|nil
---@return table[]
function M.build_footer_items(repos, current_user)
	local groups = repos or {}
	local pr_count = 0
	local repo_names = {}
	local seen = {}

	for _, group in ipairs(groups) do
		pr_count = pr_count + #(group.prs or {})
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

local function columns()
	return {
		{ key = "pr_icon", name = "", min_width = 1, can_grow = false, header_hl = "AtlasColumnHeader" },
		{ key = "repo_pr", name = "PR", min_width = 42, header_hl = "AtlasColumnHeader" },
		{
			key = "comments",
			name = icons.entity("comments"),
			min_width = 2,
			can_grow = false,
			header_hl = "AtlasColumnHeader",
		},
		{
			key = "tasks",
			name = icons.entity("tasks"),
			min_width = 2,
			can_grow = false,
			header_hl = "AtlasColumnHeader",
		},
		{
			key = "author",
			name = string.format("%s Author", icons.entity("user")),
			min_width = 3,
			can_grow = false,
			header_hl = "AtlasColumnHeader",
		},
		{
			key = "repo",
			name = string.format("%s Repo", icons.entity("repo")),
			min_width = 5,
			can_grow = false,
			header_hl = "AtlasColumnHeader",
		},
		{ key = "created", name = icons.entity("created"), can_grow = false, header_hl = "AtlasColumnHeader" },
		{ key = "updated", name = icons.entity("updated"), can_grow = false, header_hl = "AtlasColumnHeader" },
	}
end

local function plain_tree_columns()
	return {
		{ key = "name", name = "PR", min_width = 42, header_hl = "AtlasColumnHeader" },
		{
			key = "comments",
			name = icons.entity("comments"),
			min_width = 2,
			can_grow = false,
			header_hl = "AtlasColumnHeader",
		},
		{
			key = "tasks",
			name = icons.entity("tasks"),
			min_width = 2,
			can_grow = false,
			header_hl = "AtlasColumnHeader",
		},
		{
			key = "author",
			name = string.format("%s Author", icons.entity("user")),
			min_width = 3,
			can_grow = false,
			header_hl = "AtlasColumnHeader",
		},
		{
			key = "branch",
			name = string.format("%s Branch", icons.entity("branch")),
			max_width = 28,
			can_grow = false,
			header_hl = "AtlasColumnHeader",
		},
		{ key = "created", name = icons.entity("created"), can_grow = false, header_hl = "AtlasColumnHeader" },
		{ key = "updated", name = icons.entity("updated"), can_grow = false, header_hl = "AtlasColumnHeader" },
	}
end

local function append_compact_group_rows(rows, group)
	local full_name = string.format("%s/%s", tostring(group.workspace or ""), tostring(group.repo or ""))
	local repo_ctx = {
		kind = "repo",
		workspace = group.workspace,
		repo_slug = group.repo,
		full_name = full_name,
	}

	for _, pr in ipairs(group.prs or {}) do
		local author_name = tostring((pr.author and pr.author.name) or "Unknown")
		local repo_name = full_name
		local source_branch = tostring((((pr.source or {}).branch) or "?"))
		local target_branch = tostring((((pr.destination or {}).branch) or "?"))
		table.insert(rows, {
			kind = "pr",
			pr_icon = icons.entity("pr"),
			repo_pr = string.format("#%s %s", tostring(pr.id), pr.title or ""),
			comments = tostring(pr.comments),
			tasks = tostring(pr.tasks),
			author = string.format("%s %s", icons.entity("user"), author_name),
			author_hl = author_name,
			repo = string.format("%s %s", icons.entity("repo"), repo_name),
			repo_hl = repo_name,
			created = utils.relative_time(pr.created_on),
			updated = utils.relative_time(pr.updated_on),
			_item = { kind = "pr", id = pr.id, repo = full_name, pr = pr, _repo = repo_ctx },
		})

		table.insert(rows, {
			kind = "meta",
			pr_icon = "",
			repo_pr = string.format("%s → %s", source_branch, target_branch),
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
				repo = full_name,
				pr = pr,
				_repo = repo_ctx,
			},
		})
	end
end

---@param repo_groups BitbucketPRViewGroup[]
---@return { rows: table[], columns: table[] }
function M.build_compact_table(repo_groups)
	local rows = {}
	for _, group in ipairs(repo_groups or {}) do
		append_compact_group_rows(rows, group)
	end
	return {
		rows = rows,
		columns = columns(),
	}
end

---@param repo_groups BitbucketPRViewGroup[]
---@return { rows: table[], columns: table[] }
function M.build_plain_tree_table(repo_groups)
	local rows = {}
	for _, group in ipairs(repo_groups or {}) do
		local full_name = string.format("%s/%s", tostring(group.workspace or ""), tostring(group.repo or ""))
		local repo_row = {
			kind = "repo",
			repo_name = full_name,
			name = string.format("%s %s", icons.entity("repo"), full_name),
			branch = "",
			comments = "",
			tasks = "",
			author = "",
			created = "",
			updated = "",
			expanded = true,
			children = {},
			_item = {
				kind = "repo",
				repo = full_name,
				workspace = group.workspace,
				repo_slug = group.repo,
				full_name = full_name,
			},
		}

		for _, pr in ipairs(group.prs or {}) do
			local author_name = tostring((pr.author and pr.author.name) or "Unknown")
			local source_branch = tostring((((pr.source or {}).branch) or "?"))
			local target_branch = tostring((((pr.destination or {}).branch) or "?"))
			table.insert(repo_row.children, {
				kind = "pr",
				name = string.format("%s #%s %s", icons.entity("pr"), tostring(pr.id), pr.title or ""),
				branch = string.format("%s -> %s", source_branch, target_branch),
				comments = tostring(pr.comments),
				tasks = tostring(pr.tasks),
				author = string.format("%s %s", icons.entity("user"), author_name),
				author_hl = author_name,
				created = utils.relative_time(pr.created_on),
				updated = utils.relative_time(pr.updated_on),
				_item = {
					kind = "pr",
					id = pr.id,
					repo = full_name,
					pr = pr,
					_repo = {
						kind = "repo",
						workspace = group.workspace,
						repo_slug = group.repo,
						full_name = full_name,
					},
				},
			})
		end

		if #repo_row.children > 0 then
			table.insert(rows, repo_row)
		end
	end

	return {
		rows = rows,
		columns = plain_tree_columns(),
	}
end

return M
