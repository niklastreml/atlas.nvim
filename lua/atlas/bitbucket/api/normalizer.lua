local M = {}

---@param raw_values table[]
---@return BitbucketPR[]
function M.normalize_prs(raw_values)
	local out = {}

	for _, pr in ipairs(raw_values or {}) do
		local repo_full = (pr.repository and pr.repository.full_name)
			or (pr.destination and pr.destination.repository and pr.destination.repository.full_name)
			or "unknown/unknown"

		table.insert(out, {
			id = tonumber(pr.id) or 0,
			title = pr.title or "",
			description = pr.description or "",
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
					or "",
			},
			links = {
				self = ((pr.links or {}).self or {}).href or "",
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
			source_branch = pr.source and pr.source.branch and pr.source.branch.name or "?",
			target_branch = pr.destination and pr.destination.branch and pr.destination.branch.name or "?",
			created_on = pr.created_on or "",
			updated_on = pr.updated_on or "",
			_raw = pr,
		})
	end

	return out
end

return M
