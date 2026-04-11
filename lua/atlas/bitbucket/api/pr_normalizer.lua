local M = {}

---@param v any
---@return table|nil
local function as_table(v)
	if type(v) == "table" then
		return v
	end
	return nil
end

---@param v any
---@return number|nil
local function as_number_or_nil(v)
	local n = tonumber(v)
	if n == nil then
		return nil
	end
	return n
end

---@param value any
---@return "SUCCESSFUL"|"FAILED"|"INPROGRESS"|"STOPPED"|"UNKNOWN"
local function status_state(value)
	local s = tostring(value or "")
	if s == "SUCCESSFUL" or s == "FAILED" or s == "INPROGRESS" or s == "STOPPED" then
		return s
	end
	return "UNKNOWN"
end

---@param user table|nil
---@return BitbucketPRAuthor
local function actor(user)
	local u = as_table(user) or {}
	return {
		name = tostring(u.display_name or "Unknown"),
		account_id = tostring(u.account_id or ""),
		nickname = tostring(u.nickname or ""),
	}
end

---@param raw_inline table|nil
---@return BitbucketPRCommentInline|nil
local function comment_inline(raw_inline)
	local inline = as_table(raw_inline)
	if inline == nil then
		return nil
	end

	local from = as_number_or_nil(inline["from"])
	local to = as_number_or_nil(inline["to"])
	local start_from = as_number_or_nil(inline.start_from)
	local start_to = as_number_or_nil(inline.start_to)
	local path = tostring(inline.path or "")

	if from == nil and to == nil and start_from == nil and start_to == nil and path == "" then
		return nil
	end

	return {
		["from"] = from,
		["to"] = to,
		start_from = start_from,
		start_to = start_to,
		path = path,
	}
end

---@param result table|nil
---@param workspace string|nil
---@param repo string|nil
---@return BitbucketPR[]
function M.pullrequests(result, workspace, repo)
	local payload = as_table(result) or {}
	local out = {}
	local ws = tostring(workspace or "")
	local rp = tostring(repo or "")

	for _, item in ipairs(payload.values or {}) do
		local pr = as_table(item) or {}
		local author = as_table(pr.author) or {}
		local links = as_table(pr.links) or {}
		local source = as_table(pr.source) or {}
		local destination = as_table(pr.destination) or {}
		local source_repo = as_table(source.repository) or {}
		local destination_repo = as_table(destination.repository) or {}
		local source_branch = as_table(source.branch) or {}
		local source_commit = as_table(source.commit) or {}
		local destination_branch = as_table(destination.branch) or {}
		local destination_commit = as_table(destination.commit) or {}
		local repo_slug = tostring(destination_repo.slug or source_repo.slug or rp)
		local repo_full_name = tostring(destination_repo.full_name or source_repo.full_name or "")
		if repo_full_name == "" and ws ~= "" and repo_slug ~= "" then
			repo_full_name = string.format("%s/%s", ws, repo_slug)
		end

		table.insert(out, {
			id = tonumber(pr.id) or 0,
			title = tostring(pr.title or ""),
			description = tostring(pr.description or ""),
			comments = tonumber(pr.comment_count) or 0,
			tasks = tonumber(pr.task_count) or 0,
			author = {
				name = tostring(author.display_name or ""),
				account_id = tostring(author.account_id or ""),
				nickname = tostring(author.nickname or ""),
			},
			is_draft = pr.draft == true,
			state = tostring(pr.state or ""),
			links = {
				html = tostring((as_table(links.html) or {}).href or ""),
				self = tostring((as_table(links.self) or {}).href or ""),
				merge = tostring((as_table(links.merge) or {}).href or ""),
				commits = tostring((as_table(links.commits) or {}).href or ""),
				approve = tostring((as_table(links.approve) or {}).href or ""),
				request_changes = tostring((as_table(links["request-changes"]) or {}).href or ""),
				diff = tostring((as_table(links.diff) or {}).href or ""),
				diffstat = tostring((as_table(links.diffstat) or {}).href or ""),
				comments = tostring((as_table(links.comments) or {}).href or ""),
				activity = tostring((as_table(links.activity) or {}).href or ""),
				statuses = tostring((as_table(links.statuses) or {}).href or ""),
			},
			destination = {
				branch = tostring(destination_branch.name or ""),
				commit_hash = tostring(destination_commit.hash or ""),
			},
			source = {
				branch = tostring(source_branch.name or ""),
				commit_hash = tostring(source_commit.hash or ""),
			},
			close_source_branch = pr.close_source_branch == true,
			created_on = tostring(pr.created_on or ""),
			updated_on = tostring(pr.updated_on or ""),
			workspace = ws,
			repo = repo_slug,
			repo_slug = repo_slug,
			repo_full_name = repo_full_name,
		})
	end

	return out
end

---@param result table|nil
---@param workspace string|nil
---@param repo string|nil
---@return BitbucketPR|nil
function M.pullrequest(result, workspace, repo)
	local items = M.pullrequests({ values = { result } }, workspace, repo)
	return items[1]
end

---@param result table|nil
---@param workspace string|nil
---@param repo string|nil
---@return BitbucketPRDetail|nil
function M.pr_detail(result, workspace, repo)
	local base = M.pullrequest(result, workspace, repo)
	if not base then
		return nil
	end

	local payload = as_table(result) or {}
	local reviewers = {}
	for _, item in ipairs(payload.reviewers or {}) do
		local reviewer = as_table(item) or {}
		table.insert(reviewers, {
			name = tostring(reviewer.display_name or ""),
			account_id = tostring(reviewer.account_id or ""),
			nickname = tostring(reviewer.nickname or ""),
		})
	end

	local participants = {}
	local approvals_count = 0
	local changes_requested_count = 0

	for _, item in ipairs(payload.participants or {}) do
		local participant = as_table(item) or {}
		local user = as_table(participant.user) or {}
		local state = participant.state
		if state ~= "approved" and state ~= "changes_requested" and state ~= "pending" then
			state = participant.approved == true and "approved" or nil
		end

		table.insert(participants, {
			name = tostring(user.display_name or ""),
			account_id = tostring(user.account_id or ""),
			nickname = tostring(user.nickname or ""),
			role = tostring(participant.role or ""),
			approved = participant.approved == true,
			state = state,
			participated_on = participant.participated_on ~= nil and tostring(participant.participated_on) or nil,
		})

		if tostring(participant.role or "") == "REVIEWER" then
			if state == "approved" then
				approvals_count = approvals_count + 1
			elseif state == "changes_requested" then
				changes_requested_count = changes_requested_count + 1
			end
		end
	end

	return vim.tbl_extend("force", base, {
		reviewers = reviewers,
		participants = participants,
		approvals_count = approvals_count,
		changes_requested_count = changes_requested_count,
	})
end

---@param result table|nil
---@return BitbucketPRDiffstat
function M.pr_diffstat(result)
	local payload = as_table(result) or {}
	local out = {}

	for _, item in ipairs(payload.values or {}) do
		local entry = as_table(item) or {}
		local old_file = as_table(entry.old)
		local new_file = as_table(entry.new)

		table.insert(out, {
			status = tostring(entry.status or ""),
			lines_added = tonumber(entry.lines_added) or 0,
			lines_removed = tonumber(entry.lines_removed) or 0,
			old_file = old_file and {
				path = tostring(old_file.path or ""),
				type = tostring(old_file.type or ""),
			} or nil,
			new_file = new_file and {
				path = tostring(new_file.path or ""),
				type = tostring(new_file.type or ""),
			} or nil,
		})
	end

	return {
		entries = out,
		size = tonumber(payload.size) or #out,
	}
end

---@param result table|nil
---@return BitbucketPRCommits
function M.pr_commits(result)
	local payload = as_table(result) or {}
	local entries = {}

	for _, item in ipairs(payload.values or {}) do
		local commit = as_table(item) or {}
		local hash = tostring(commit.hash or "")
		local author_user = as_table((as_table(commit.author) or {}).user) or {}
		local links = as_table(commit.links) or {}
		local message = tostring(commit.message or "")
		message = message:gsub("\r\n", "\n"):gsub("\n+$", "")

		table.insert(entries, {
			hash = hash,
			short_hash = (hash ~= "" and hash:sub(1, 12)) or "",
			date = tostring(commit.date or ""),
			message = message,
			author_name = tostring(author_user.display_name or "Unknown"),
			author_nickname = tostring(author_user.nickname or ""),
			html_url = tostring((as_table(links.html) or {}).href or ""),
			statuses_url = tostring((as_table(links.statuses) or {}).href or ""),
		})
	end

	return {
		entries = entries,
		page = tonumber(payload.page) or 1,
	}
end

---@param result table|nil
---@return BitbucketPRStatuses
function M.pr_statuses(result)
	local payload = as_table(result) or {}
	local entries = {}

	for _, item in ipairs(payload.values or {}) do
		local status = as_table(item) or {}
		local commit = as_table(status.commit) or {}

		table.insert(entries, {
			key = tostring(status.key or ""),
			type = tostring(status.type or ""),
			state = status_state(status.state),
			name = tostring(status.name or ""),
			refname = tostring(status.refname or ""),
			description = tostring(status.description or ""),
			url = tostring(status.url or ""),
			created_on = tostring(status.created_on or ""),
			updated_on = tostring(status.updated_on or ""),
			commit_hash = tostring(commit.hash or ""),
		})
	end

	return {
		entries = entries,
		size = payload.size ~= nil and tonumber(payload.size) or nil,
	}
end

---@param result table|nil
---@return BitbucketPRActivity
function M.pr_activity(result)
	local payload = as_table(result) or {}
	local entries = {}

	for _, item in ipairs(payload.values or {}) do
		local entry = as_table(item) or {}
		local update = as_table(entry.update)
		local approval = as_table(entry.approval)
		local comment = as_table(entry.comment)

		if update ~= nil then
			local source = as_table(update.source) or {}
			local destination = as_table(update.destination) or {}
			table.insert(entries, {
				kind = "update",
				date = tostring(update.date or ""),
				actor = actor(update.author),
				state = tostring(update.state or ""),
				draft = update.draft == true,
				title = tostring(update.title or ""),
				description = tostring(update.description or ""),
				reason = tostring(update.reason or ""),
				details = tostring(update.details or ""),
				source_branch = tostring((((source or {}).branch or {}).name or "")),
				target_branch = tostring((((destination or {}).branch or {}).name or "")),
				source_commit_hash = tostring((((source or {}).commit or {}).hash or "")),
				target_commit_hash = tostring((((destination or {}).commit or {}).hash or "")),
				changes = as_table(update.changes) or {},
			})
		elseif approval ~= nil then
			table.insert(entries, {
				kind = "approval",
				date = tostring(approval.date or ""),
				actor = actor(approval.user),
			})
		elseif comment ~= nil then
			local content = as_table(comment.content) or {}
			table.insert(entries, {
				kind = "comment",
				date = tostring(comment.created_on or ""),
				updated_on = tostring(comment.updated_on or ""),
				actor = actor(comment.user),
				id = tonumber(comment.id) or 0,
				content_raw = tostring(content.raw or ""),
				deleted = comment.deleted == true,
				pending = comment.pending == true,
			})
		end
	end

	return {
		entries = entries,
		next = payload.next ~= nil and tostring(payload.next) or nil,
	}
end

---@param result table|nil
---@return BitbucketPRComments
function M.pr_comments(result)
	local payload = as_table(result) or {}
	local entries = {}

	for _, item in ipairs(payload.values or {}) do
		local entry = as_table(item) or {}
		local content = as_table(entry.content) or {}
		local links = as_table(entry.links) or {}
		local code_link = as_table(links.code)
		local parent = as_table(entry.parent)

		table.insert(entries, {
			id = tonumber(entry.id) or 0,
			created_on = tostring(entry.created_on or ""),
			updated_on = tostring(entry.updated_on or ""),
			content = {
				type = tostring(content.type or ""),
				raw = tostring(content.raw or ""),
				markup = tostring(content.markup or ""),
				html = tostring(content.html or ""),
			},
			author = actor(entry.user),
			deleted = entry.deleted == true,
			pending = entry.pending == true,
			comment_type = tostring(entry.type or ""),
			parent_id = parent ~= nil and tonumber(parent.id) or nil,
			links = {
				self = tostring((as_table(links.self) or {}).href or ""),
				html = tostring((as_table(links.html) or {}).href or ""),
				code = code_link ~= nil and tostring(code_link.href or "") or nil,
			},
			inline = comment_inline(entry.inline),
		})
	end

	return {
		entries = entries,
		size = payload.size ~= nil and tonumber(payload.size) or nil,
		page = payload.page ~= nil and tonumber(payload.page) or nil,
		pagelen = payload.pagelen ~= nil and tonumber(payload.pagelen) or nil,
		next = payload.next ~= nil and tostring(payload.next) or nil,
	}
end

---@param result table|nil
---@return BitbucketPRTasks
function M.pr_tasks(result)
	local payload = as_table(result) or {}
	local entries = {}

	for _, item in ipairs(payload.values or {}) do
		local task = as_table(item) or {}
		local content = as_table(task.content) or {}
		local links = as_table(task.links) or {}
		local comment = as_table(task.comment)
		local comment_links = as_table(comment and comment.links or nil) or {}

		table.insert(entries, {
			id = tonumber(task.id) or 0,
			state = tostring(task.state or ""),
			content_raw = tostring(content.raw or ""),
			created_on = tostring(task.created_on or ""),
			updated_on = tostring(task.updated_on or ""),
			resolved_on = task.resolved_on ~= nil and tostring(task.resolved_on) or nil,
			pending = task.pending == true,
			creator = actor(task.creator),
			comment_id = comment ~= nil and tonumber(comment.id) or nil,
			links = {
				self = tostring((as_table(links.self) or {}).href or ""),
				html = tostring((as_table(links.html) or {}).href or ""),
			},
			comment_html = tostring((as_table(comment_links.html) or {}).href or ""),
		})
	end

	return {
		entries = entries,
		size = payload.size ~= nil and tonumber(payload.size) or nil,
		page = payload.page ~= nil and tonumber(payload.page) or nil,
		pagelen = payload.pagelen ~= nil and tonumber(payload.pagelen) or nil,
		next = payload.next ~= nil and tostring(payload.next) or nil,
	}
end

return M
