local M = {}

---@param ... string|nil
---@return string
local function first_non_empty(...)
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		if type(value) == "string" and value ~= "" then
			return value
		end
	end
	return ""
end

---@param pr table
---@return BitbucketPR
local function normalize_pr(pr)
	local repo_full = (pr.repository and pr.repository.full_name)
		or (pr.destination and pr.destination.repository and pr.destination.repository.full_name)
		or (pr.source and pr.source.repository and pr.source.repository.full_name)
		or "unknown/unknown"

	return {
		id = tonumber(pr.id) or 0,
		title = pr.title or "",
		description = first_non_empty(((pr.rendered or {}).description or {}).raw, pr.description, ((pr.summary or {}).raw)),
		comments = tonumber(pr.comment_count) or 0,
		tasks = tonumber(pr.task_count) or 0,
		author = {
			name = (pr.author and pr.author.display_name) or "Unknown",
			account_id = (pr.author and pr.author.account_id) or "",
			nickname = (pr.author and pr.author.nickname) or "",
		},
		is_draft = pr.draft == true,
		state = pr.state or "OPEN",
		repo = {
			name = repo_full,
			link = (
				pr.repository
				and pr.repository.links
				and pr.repository.links.html
				and pr.repository.links.html.href
			)
				or (pr.destination and pr.destination.repository and pr.destination.repository.links and pr.destination.repository.links.html and pr.destination.repository.links.html.href)
				or (pr.source and pr.source.repository and pr.source.repository.links and pr.source.repository.links.html and pr.source.repository.links.html.href)
				or "",
		},
		links = {
			self = ((pr.links or {}).self or {}).href or "",
			commits = ((pr.links or {}).commits or {}).href or "",
			approve = ((pr.links or {}).approve or {}).href or "",
			request_changes = ((pr.links or {})["request-changes"] or {}).href or "",
			diff = ((pr.links or {}).diff or {}).href or "",
			diffstat = ((pr.links or {}).diffstat or {}).href or "",
			comments = ((pr.links or {}).comments or {}).href or "",
			activity = ((pr.links or {}).activity or {}).href or "",
			statuses = ((pr.links or {}).statuses or {}).href or "",
		},
		summary = {
			raw = (pr.summary and pr.summary.raw) or "",
			html = (pr.summary and pr.summary.html) or "",
		},
		source_branch = (pr.source and pr.source.branch and pr.source.branch.name) or "?",
		target_branch = (pr.destination and pr.destination.branch and pr.destination.branch.name) or "?",
		source_commit_hash = (pr.source and pr.source.commit and pr.source.commit.hash) or "",
		close_source_branch = pr.close_source_branch == true,
		created_on = pr.created_on or "",
		updated_on = pr.updated_on or "",
		_raw = pr,
	}
end

---@param participant table
---@return "approved"|"changes_requested"|"pending"
local function participant_decision(participant)
	local state = participant and participant.state
	if state == "approved" then
		return "approved"
	end
	if state == "changes_requested" then
		return "changes_requested"
	end
	if state == nil or state == "" then
		if participant and participant.approved == true then
			return "approved"
		end
		return "pending"
	end
	return "pending"
end

---@param v any
---@return table|nil
local function as_table(v)
	if type(v) == "table" then
		return v
	end
	return nil
end

---@param user table|nil
---@return BitbucketPRActivityActor
local function normalize_activity_actor(user)
	local u = as_table(user) or {}
	return {
		name = tostring(u.display_name or "Unknown"),
		account_id = tostring(u.account_id or ""),
		nickname = tostring(u.nickname or ""),
	}
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

---@param raw_inline table|nil
---@return BitbucketPRCommentInline|nil
local function normalize_comment_inline(raw_inline)
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

---@param raw_values table[]
---@return BitbucketPR[]
function M.normalize_prs(raw_values)
	local out = {}

	for _, pr in ipairs(raw_values or {}) do
		table.insert(out, normalize_pr(pr))
	end

	return out
end

---@param raw_pr table
---@return BitbucketPRDetail
function M.normalize_pr_detail(raw_pr)
	local base = normalize_pr(raw_pr)

	local reviewers = {}
	for _, reviewer in ipairs(raw_pr.reviewers or {}) do
		table.insert(reviewers, {
			name = reviewer.display_name or "Unknown",
			account_id = reviewer.account_id or "",
			nickname = reviewer.nickname or "",
		})
	end

	local participants = {}
	local decisions = {}
	local approvals_count = 0
	local changes_requested_count = 0

	for _, participant in ipairs(raw_pr.participants or {}) do
		local user = participant.user or {}
		local decision = participant_decision(participant)
		local role = participant.role or ""

		table.insert(participants, {
			account_id = user.account_id or "",
			name = user.display_name or "Unknown",
			nickname = user.nickname or "",
			role = role,
			approved = participant.approved == true,
			state = participant.state,
			participated_on = participant.participated_on,
		})

		if role == "REVIEWER" then
			if decision == "approved" then
				approvals_count = approvals_count + 1
			elseif decision == "changes_requested" then
				changes_requested_count = changes_requested_count + 1
			end

			table.insert(decisions, {
				account_id = user.account_id or "",
				name = user.display_name or "Unknown",
				nickname = user.nickname or "",
				decision = decision,
				approved = participant.approved == true,
				participated_on = participant.participated_on,
			})
		end
	end

	return vim.tbl_extend("force", base, {
		reviewers = reviewers,
		participants = participants,
		decisions = decisions,
		approvals_count = approvals_count,
		changes_requested_count = changes_requested_count,
	})
end

---@param result table
---@return BitbucketPRActivity
function M.normalize_pr_activity(result)
	local entries = {}

	for _, item in ipairs((result and result.values) or {}) do
		local update = as_table(item.update)
		local approval = as_table(item.approval)
		local comment = as_table(item.comment)

		if update ~= nil then
			local source = as_table(update.source) or {}
			local destination = as_table(update.destination) or {}
			table.insert(entries, {
				kind = "update",
				date = tostring(update.date or ""),
				actor = normalize_activity_actor(update.author),
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
				actor = normalize_activity_actor(approval.user),
			})
		elseif comment ~= nil then
			local content = as_table(comment.content) or {}
			table.insert(entries, {
				kind = "comment",
				date = tostring(comment.created_on or ""),
				updated_on = tostring(comment.updated_on or ""),
				actor = normalize_activity_actor(comment.user),
				id = tonumber(comment.id) or 0,
				content_raw = tostring(content.raw or ""),
				deleted = comment.deleted == true,
				pending = comment.pending == true,
			})
		end
	end

	return {
		entries = entries,
		size = tonumber(result and result.size) or #entries,
	}
end

---@param result table
---@return BitbucketPRComments
function M.normalize_pr_comments(result)
	local flat_entries = {}
	local by_id = {}

	for _, item in ipairs((result and result.values) or {}) do
		local parent = as_table(item.parent)
		local content = as_table(item.content) or {}
		local links = as_table(item.links) or {}

		local entry = {
			id = tonumber(item.id) or 0,
			parent_id = as_number_or_nil(parent and parent.id),
			created_on = tostring(item.created_on or ""),
			updated_on = tostring(item.updated_on or ""),
			content = {
				type = tostring(content.type or ""),
				raw = tostring(content.raw or ""),
				markup = tostring(content.markup or ""),
				html = tostring(content.html or ""),
			},
			author = normalize_activity_actor(item.user),
			deleted = item.deleted == true,
			pending = item.pending == true,
			comment_type = tostring(item.type or ""),
			links = {
				self = tostring(((as_table(links.self) or {}).href) or ""),
				html = tostring(((as_table(links.html) or {}).href) or ""),
				code = tostring(((as_table(links.code) or {}).href) or ""),
			},
			inline = normalize_comment_inline(item.inline),
			children = {},
		}

		table.insert(flat_entries, entry)
		if entry.id > 0 then
			by_id[entry.id] = entry
		end
	end

	local roots = {}
	for _, entry in ipairs(flat_entries) do
		local parent_id = entry.parent_id
		if parent_id ~= nil and by_id[parent_id] ~= nil then
			table.insert(by_id[parent_id].children, entry)
		else
			table.insert(roots, entry)
		end
	end

	return {
		entries = roots,
		size = tonumber(result and result.size) or #flat_entries,
		page = tonumber(result and result.page) or 1,
		pagelen = tonumber(result and result.pagelen) or #flat_entries,
	}
end

return M
