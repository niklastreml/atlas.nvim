local M = {}

---@param comment JiraComment|nil
---@param current_user JiraUser|nil
---@return boolean
function M.can_manage_comment(comment, current_user)
	if type(comment) ~= "table" then
		return false
	end

	local author_id = tostring((comment.author or {}).account_id or "")
	local current_user_id = tostring((current_user or {}).account_id or "")
	return author_id ~= "" and current_user_id ~= "" and author_id == current_user_id
end

---@param comments JiraComment[]|nil
function M.sort_comments_by_created(comments)
	if type(comments) ~= "table" then
		return
	end

	table.sort(comments, function(a, b)
		local ac = tostring((a and a.created) or "")
		local bc = tostring((b and b.created) or "")
		if ac == bc then
			return tostring((a and a.id) or "") < tostring((b and b.id) or "")
		end
		return ac > bc
	end)
end

---@param comments JiraComment[]|nil
local function sort_comment_children(comments)
	if type(comments) ~= "table" then
		return
	end

	for _, comment in ipairs(comments) do
		if type(comment) == "table" and type(comment.children) == "table" and #comment.children > 0 then
			table.sort(comment.children, function(a, b)
				local ac = tostring((a and a.created) or "")
				local bc = tostring((b and b.created) or "")
				if ac == bc then
					return tostring((a and a.id) or "") < tostring((b and b.id) or "")
				end
				return ac < bc
			end)
			sort_comment_children(comment.children)
		end
	end
end

---@param comments JiraComment[]|nil
function M.rebuild_comment_tree(comments)
	if type(comments) ~= "table" then
		return
	end

	local by_id = {}
	for _, comment in ipairs(comments) do
		if type(comment) == "table" then
			comment.children = {}
			by_id[tostring(comment.id or "")] = comment
		end
	end

	for _, comment in ipairs(comments) do
		if type(comment) == "table" and comment.parent_id ~= nil then
			local parent = by_id[tostring(comment.parent_id)]
			if parent ~= nil then
				table.insert(parent.children, comment)
			end
		end
	end

	sort_comment_children(comments)
end

---@param comments JiraComment[]|nil
---@param comment_id string
---@return JiraComment[]
function M.remove_comment(comments, comment_id)
	if type(comments) ~= "table" then
		return {}
	end

	local target_id = tostring(comment_id or "")
	if target_id == "" then
		return comments
	end

	local next_comments = {}
	for _, comment in ipairs(comments) do
		local id = tostring(comment and comment.id or "")
		if id ~= target_id then
			table.insert(next_comments, comment)
		end
	end

	return next_comments
end

--- Jira api returns parentID, but if the parent field is missing (e.g. due to deletion), we simply assume the parent comment is deleted and add a placeholder for it.
---@param comments JiraComment[]|nil
---@return JiraComment[]
function M.ensure_deleted_parents(comments)
	if type(comments) ~= "table" then
		return {}
	end

	local by_id = {}
	for _, comment in ipairs(comments) do
		local id = tostring(comment and comment.id or "")
		if id ~= "" then
			by_id[id] = true
		end
	end

	local missing = {}
	for _, comment in ipairs(comments) do
		local pid = tostring(comment and comment.parent_id or "")
		if pid ~= "" and not by_id[pid] then
			missing[pid] = true
		end
	end

	for parent_id, _ in pairs(missing) do
		table.insert(comments, {
			id = parent_id,
			self = "",
			author = {
				account_id = "",
				display_name = "unknown",
				email = nil,
			},
			body = "Comment deleted",
			_body = nil,
			created = "",
			updated = "",
			parent_id = nil,
			jsd_public = true,
			children = {},
		})
	end

	return comments
end

return M
