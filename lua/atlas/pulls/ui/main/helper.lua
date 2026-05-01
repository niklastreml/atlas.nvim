local M = {}

local highlights = require("atlas.ui.shared.highlights")
local icons = require("atlas.ui.shared.icons")
local utils = require("atlas.ui.shared.utils")
local state = require("atlas.pulls.state")

local PR_ICON = icons.pulls("pr")
local REPO_ICON = icons.pulls("repo")
local TASKS_ICON = icons.pulls("tasks")

---@param pr PullRequest
---@return string
local function pr_icon_or_spinner(pr)
	if state.is_pr_reloading(pr.repo_full_name, pr.id) then
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

---@param state_str string|nil
---@return string
function M.status_badge_hl(state_str)
	local lower = tostring(state_str or ""):lower()
	if lower == "" then
		return "AtlasTextMuted"
	end
	return highlights.dynamic_for_bg("pr-state:" .. lower) or "AtlasTextMuted"
end

---@return integer
local function active_filter_count()
	local count = 0
	for _, enabled in pairs(state.status_filters or {}) do
		if enabled then
			count = count + 1
		end
	end
	return count
end

---@param view AtlasPullsViewConfig|nil
---@return string
function M.view_id(view)
	if view == nil then
		return "default"
	end
	return view.key or view.name or "default"
end

---@param a AtlasPullsViewConfig|nil
---@param b AtlasPullsViewConfig|nil
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
		local hl_group = highlights.dynamic_for(row.repo_full_name)
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
	if col.key == "status" then
		local hl_group = M.status_badge_hl(row.status_raw)
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
	local cols = {
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
	}
	if active_filter_count() > 1 then
		table.insert(cols, {
			key = "status",
			name = "Status",
			min_width = 6,
			can_grow = false,
			header_hl = "AtlasColumnHeader",
		})
	end
	vim.list_extend(cols, {
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
	})
	return cols
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
			local is_reloading = state.is_pr_reloading(pr.repo_full_name, pr.id)
			local state_str = tostring(pr.state or "")
			local state_label = state_str ~= "" and (" " .. state_str:sub(1, 1):upper() .. state_str:sub(2):lower() .. " ") or ""
			local author_display = utils.shorten_name(author_name, 20)
			table.insert(rows, {
				kind = "pr",
				pr_icon = pr_icon_or_spinner(pr),
				_pr_reloading = is_reloading,
				repo_pr = "#" .. id_str .. " " .. title,
				comments = tostring(pr.comments_count or 0),
				tasks = tostring(pr.tasks_count or 0),
				status = state_label,
				status_raw = state_str,
				author = string.format("%s %s", icons.general("user"), author_display),
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
				status = "",
				status_raw = "",
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
	local cols = {
		{ key = "name", name = "PR", min_width = 42, header_hl = "AtlasColumnHeader" },
		{
			key = "comments",
			name = icons.general("comment"),
			min_width = 2,
			can_grow = false,
			header_hl = "AtlasColumnHeader",
		},
		{ key = "tasks", name = TASKS_ICON, min_width = 2, can_grow = false, header_hl = "AtlasColumnHeader" },
	}
	if active_filter_count() > 1 then
		table.insert(cols, {
			key = "status",
			name = "Status",
			min_width = 6,
			can_grow = false,
			header_hl = "AtlasColumnHeader",
		})
	end
	vim.list_extend(cols, {
		{
			key = "author",
			name = string.format("%s Author", icons.general("user")),
			min_width = 3,
			can_grow = false,
			header_hl = "AtlasColumnHeader",
		},
		{
			key = "branch",
			name = string.format("%s Branch", icons.pulls("branch")),
			max_width = 28,
			can_grow = false,
			header_hl = "AtlasColumnHeader",
		},
		{ key = "created", name = icons.general("created"), can_grow = false, header_hl = "AtlasColumnHeader" },
		{ key = "updated", name = icons.general("updated"), can_grow = false, header_hl = "AtlasColumnHeader" },
	})
	return cols
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
			local is_reloading = state.is_pr_reloading(pr.repo_full_name, pr.id)
			local state_str = tostring(pr.state or "")
			local state_label = state_str ~= "" and (" " .. state_str:sub(1, 1):upper() .. state_str:sub(2):lower() .. " ") or ""
			local author_display = utils.shorten_name(author_name, 20)
			table.insert(children, {
				kind = "pr",
				name = icon .. " #" .. id_str .. " " .. title,
				_pr_reloading = is_reloading,
				comments = tostring(pr.comments_count or 0),
				tasks = tostring(pr.tasks_count or 0),
				status = state_label,
				status_raw = state_str,
				author = string.format("%s %s", icons.general("user"), author_display),
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
			repo_full_name = repo_label,
			comments = "",
			tasks = "",
			status = "",
			status_raw = "",
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

---@param pr PullRequest
---@return string[], table[]
function M.pr_popup_content(pr)
	local id = tostring(pr.id or "")
	local title = tostring(pr.title or "")
	local author_name = tostring((pr.author and pr.author.name) or "Unknown")
	local repo_name = tostring(pr.repo_full_name or "")

	local lines = {
		string.format(" #%s: %s", id, title),
		"",
		string.format(" State:    %s", tostring(pr.state or "-")),
		string.format(" Author:   %s", author_name),
		string.format(" Repo:     %s", repo_name ~= "" and repo_name or "-"),
		string.format(
			" Branch:   %s -> %s",
			tostring((pr.source or {}).branch or "?"),
			tostring((pr.destination or {}).branch or "?")
		),
		string.format(" Comments: %s", tostring(pr.comments_count or 0)),
		string.format(" Tasks:    %s", tostring(pr.tasks_count or 0)),
		string.format(" Updated:  %s", utils.relative_time(pr.updated_on)),
	}

	local content_width = 1
	for _, line in ipairs(lines) do
		content_width = math.max(content_width, vim.fn.strdisplaywidth(line))
	end
	lines[2] = " " .. ("━"):rep(content_width)

	local hl = {
		{ row = 1, col = 0, end_col = -1, hl_group = "AtlasTextMuted" },
		{ row = 2, col = 1, end_col = 10, hl_group = "AtlasTextMuted" },
		{ row = 2, col = 11, end_col = -1, hl_group = M.pr_state_hl(pr.state) },
		{ row = 3, col = 1, end_col = 10, hl_group = "AtlasTextMuted" },
		{ row = 3, col = 11, end_col = -1, hl_group = M.author_hl(author_name) },
		{ row = 4, col = 1, end_col = 10, hl_group = "AtlasTextMuted" },
		{ row = 4, col = 11, end_col = -1, hl_group = M.repo_hl(repo_name) },
		{ row = 5, col = 1, end_col = 10, hl_group = "AtlasTextMuted" },
		{ row = 5, col = 11, end_col = -1, hl_group = "AtlasTextMuted" },
		{ row = 6, col = 1, end_col = 10, hl_group = "AtlasTextMuted" },
		{ row = 7, col = 1, end_col = 10, hl_group = "AtlasTextMuted" },
		{ row = 8, col = 1, end_col = 10, hl_group = "AtlasTextMuted" },
		{ row = 8, col = 11, end_col = -1, hl_group = "AtlasTextMuted" },
	}

	if id ~= "" then
		table.insert(hl, {
			row = 0,
			col = 2,
			end_col = 2 + #id,
			hl_group = "AtlasTextMuted",
		})
	end

	return lines, hl
end

return M
