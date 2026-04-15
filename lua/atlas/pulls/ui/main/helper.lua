local M = {}

local highlights = require("atlas.shared.highlights")
local icons = require("atlas.shared.icons")
local utils = require("atlas.shared.utils")
local state = require("atlas.pulls.state")

local PR_ICON = icons.pulls("pr")
local REPO_ICON = icons.pulls("repo")
local TASKS_ICON = icons.pulls("tasks")

---@param pr PullRequest
---@return string
local function pr_icon_or_spinner(pr)
	if state.is_pr_reloading(pr.repo_id, pr.id) then
		return state.reload_spinner_frame or "⠋"
	end
	return PR_ICON
end

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
		return "AtlasPROpen"
	end
	if lower == "merged" then
		return "AtlasPRMerged"
	end
	if lower == "declined" or lower == "superseded" then
		return "AtlasPRDeclined"
	end
	if lower == "draft" then
		return "AtlasPRDraft"
	end
	return "AtlasTextMuted"
end

---@param view PullsView|nil
---@return string
function M.view_id(view)
	if view == nil then
		return "default"
	end
	return view.key or view.name or "default"
end

---@param a PullsView|nil
---@param b PullsView|nil
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
---@param col table
---@param ctx { text: string, padded: string, width: integer }
---@return table[]|nil
function M.cell_hl(row, col, ctx)
	if col.key == "name" and row.kind == "repo" then
		local hl_group = highlights.dynamic_for(row.repo_name)
		return { { start_col = 0, end_col = #ctx.padded, hl_group = hl_group } }
	end
	if col.key == "name" and row.kind == "pr" then
		local is_reloading = row._pr_reloading == true
		local icon_hl = is_reloading and "AtlasTextMuted" or "AtlasTextPositive"
		local icon_start = string.find(ctx.text or "", PR_ICON, 1, true)
		if icon_start ~= nil then
			local start_col = icon_start - 1
			return { { start_col = start_col, end_col = start_col + #PR_ICON, hl_group = icon_hl } }
		end
		-- When reloading the icon is a spinner frame, just highlight the first few chars
		local frame_len = #(state.reload_spinner_frame or "⠋")
		return { { start_col = 0, end_col = frame_len, hl_group = icon_hl } }
	end
	if col.key == "pr_icon" then
		local is_reloading = row.kind == "pr" and row._pr_reloading == true
		local hl_group = is_reloading and "AtlasTextMuted" or (row.kind == "pr" and "AtlasTextPositive" or "AtlasTextMuted")
		return { { start_col = 0, end_col = #ctx.padded, hl_group = hl_group } }
	end
	if col.key == "branch" then
		return { { start_col = 0, end_col = #ctx.padded, hl_group = "AtlasTextMuted" } }
	end
	if col.key == "created" or col.key == "updated" or (row.kind == "meta" and col.key == "repo_pr") then
		return { { start_col = 0, end_col = #ctx.padded, hl_group = "AtlasTextMuted" } }
	end
	if col.key == "author" then
		local hl_group = M.author_hl(row.author_hl or row.author)
		return { { start_col = 0, end_col = #ctx.padded, hl_group = hl_group } }
	end
	if col.key == "repo" then
		local hl_group = M.repo_hl(row.repo_hl or row.repo)
		return { { start_col = 0, end_col = #ctx.padded, hl_group = hl_group } }
	end
	return nil
end

---@param groups PullsGroup[]|nil
---@param current_user PullsUser|nil
---@return table[]
function M.build_footer_items(groups, current_user)
	local repos = groups or {}
	local pr_count = 0
	local repo_names = {}
	local seen = {}
	for _, group in ipairs(repos) do
		pr_count = pr_count + #(group.prs or {})
		local name = group.repo.name
		if name ~= nil and name ~= "" and not seen[name] then
			seen[name] = true
			table.insert(repo_names, name)
		end
	end
	local items = {
		{
			text = string.format("%s %d PR%s", PR_ICON, pr_count, pr_count == 1 and "" or "s"),
			hl_group = "AtlasLogInfo",
		},
	}
	local user_name = tostring((current_user or {}).username or (current_user or {}).name or "")
	if user_name ~= "" then
		table.insert(items, {
			text = string.format("%s @%s", icons.general("user"), user_name),
			hl_group = "AtlasFooterText",
		})
	end
	for _, name in ipairs(repo_names) do
		table.insert(items, {
			text = string.format("%s %s", REPO_ICON, name),
			hl_group = "AtlasFooterText",
		})
	end
	return items
end

---@return table[]
local function compact_columns()
	return {
		{ key = "pr_icon", name = "", min_width = 1, can_grow = false, header_hl = "AtlasColumnHeader" },
		{ key = "repo_pr", name = "PR", min_width = 42, header_hl = "AtlasColumnHeader" },
		{
			key = "comments",
			name = icons.general("comment"),
			min_width = 2,
			can_grow = false,
			header_hl = "AtlasColumnHeader",
		},
		{ key = "tasks", name = TASKS_ICON, min_width = 2, can_grow = false, header_hl = "AtlasColumnHeader" },
		{
			key = "author",
			name = string.format("%s Author", icons.general("user")),
			min_width = 3,
			can_grow = false,
			header_hl = "AtlasColumnHeader",
		},
		{
			key = "repo",
			name = string.format("%s Repo", REPO_ICON),
			min_width = 5,
			can_grow = false,
			header_hl = "AtlasColumnHeader",
		},
		{ key = "created", name = icons.general("created"), can_grow = false, header_hl = "AtlasColumnHeader" },
		{ key = "updated", name = icons.general("updated"), can_grow = false, header_hl = "AtlasColumnHeader" },
	}
end

---@param groups PullsGroup[]|nil
---@return { columns: table, rows: table[] }
function M.build_compact_table(groups)
	local rows = {}
	for _, group in ipairs(groups or {}) do
		local repo_label = group.repo.name or ""
		for _, pr in ipairs(group.prs or {}) do
			local id_str = tostring(pr.id or "")
			local title = tostring(pr.title or "")
			local author_name = (pr.author and pr.author.name) and pr.author.name or ""
			local src = (pr.source and pr.source.branch) or ""
			local dst = (pr.destination and pr.destination.branch) or ""
			local is_reloading = state.is_pr_reloading(pr.repo_id, pr.id)
			table.insert(rows, {
				kind = "pr",
				pr_icon = pr_icon_or_spinner(pr),
				_pr_reloading = is_reloading,
				repo_pr = "#" .. id_str .. " " .. title,
				comments = tostring(pr.comments_count or 0),
				tasks = tostring(pr.tasks_count or 0),
				author = string.format("%s %s", icons.general("user"), author_name),
				author_hl = author_name,
				repo = string.format("%s %s", REPO_ICON, repo_label),
				repo_hl = repo_label,
				created = utils.relative_time(pr.created_on),
				updated = utils.relative_time(pr.updated_on),
				_item = {
					kind = "pr",
					id = pr.id,
					repo = group.repo,
					pr = pr,
				},
			})
			table.insert(rows, {
				kind = "meta",
				pr_icon = "",
				repo_pr = src .. " → " .. dst,
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
					repo = group.repo,
					pr = pr,
				},
			})
		end
	end
	return { columns = compact_columns(), rows = rows }
end

---@return table[]
local function plain_tree_columns()
	return {
		{ key = "name", name = "PR", min_width = 42, header_hl = "AtlasColumnHeader" },
		{
			key = "comments",
			name = icons.general("comment"),
			min_width = 2,
			can_grow = false,
			header_hl = "AtlasColumnHeader",
		},
		{ key = "tasks", name = TASKS_ICON, min_width = 2, can_grow = false, header_hl = "AtlasColumnHeader" },
		{
			key = "author",
			name = string.format("%s Author", icons.general("user")),
			min_width = 3,
			can_grow = false,
			header_hl = "AtlasColumnHeader",
		},
		{
			key = "branch",
			name = string.format("%s Branch", icons.general("branch")),
			max_width = 28,
			can_grow = false,
			header_hl = "AtlasColumnHeader",
		},
		{ key = "created", name = icons.general("created"), can_grow = false, header_hl = "AtlasColumnHeader" },
		{ key = "updated", name = icons.general("updated"), can_grow = false, header_hl = "AtlasColumnHeader" },
	}
end

---@param groups PullsGroup[]|nil
---@return { columns: table, rows: table[], tree: table }
function M.build_plain_tree_table(groups)
	local roots = {}
	for _, group in ipairs(groups or {}) do
		local repo_label = group.repo.name or ""
		local children = {}
		for _, pr in ipairs(group.prs or {}) do
			local id_str = tostring(pr.id or "")
			local title = tostring(pr.title or "")
			local author_name = (pr.author and pr.author.name) and pr.author.name or ""
			local src = (pr.source and pr.source.branch) or ""
			local dst = (pr.destination and pr.destination.branch) or ""
			local icon = pr_icon_or_spinner(pr)
			local is_reloading = state.is_pr_reloading(pr.repo_id, pr.id)
			table.insert(children, {
				kind = "pr",
				name = icon .. " #" .. id_str .. " " .. title,
				_pr_reloading = is_reloading,
				comments = tostring(pr.comments_count or 0),
				tasks = tostring(pr.tasks_count or 0),
				author = string.format("%s %s", icons.general("user"), author_name),
				author_hl = author_name,
				branch = src .. " -> " .. dst,
				created = utils.relative_time(pr.created_on),
				updated = utils.relative_time(pr.updated_on),
				_item = {
					kind = "pr",
					id = pr.id,
					repo = group.repo,
					pr = pr,
				},
			})
		end
		table.insert(roots, {
			kind = "repo",
			name = REPO_ICON .. " " .. repo_label,
			repo_name = repo_label,
			comments = "",
			tasks = "",
			author = "",
			branch = "",
			created = "",
			updated = "",
			expanded = true,
			children = children,
			_item = {
				kind = "repo",
				repo = group.repo,
			},
		})
	end
	return {
		columns = plain_tree_columns(),
		rows = roots,
		tree = {
			column_key = "name",
			children_key = "children",
			expanded_field = "expanded",
			default_expanded = true,
		},
	}
end

return M
