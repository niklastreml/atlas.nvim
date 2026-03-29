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

return M
