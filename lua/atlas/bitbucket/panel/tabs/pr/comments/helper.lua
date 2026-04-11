local M = {}

---@param comment BitbucketPRCommentEntry|nil
---@param current_user BitbucketCurrentUser|nil
---@return boolean
function M.can_manage_comment(comment, current_user)
	if type(comment) ~= "table" then
		return false
	end

	local author_id = tostring((comment.author or {}).account_id or "")
	local current_user_id = tostring((current_user or {}).account_id or "")
	return author_id ~= "" and current_user_id ~= "" and author_id == current_user_id
end

---@param a BitbucketPRCommentEntry
---@param b BitbucketPRCommentEntry
---@return boolean
local function less_by_created(a, b)
	local ac = tostring((a and a.created_on) or "")
	local bc = tostring((b and b.created_on) or "")
	if ac == bc then
		return tonumber((a and a.id) or 0) < tonumber((b and b.id) or 0)
	end
	return ac < bc
end

---@param nodes BitbucketPRCommentTreeNode[]|nil
local function sort_node_children(nodes)
	if type(nodes) ~= "table" then
		return
	end

	table.sort(nodes, function(a, b)
		return less_by_created(a.comment, b.comment)
	end)

	for _, node in ipairs(nodes) do
		sort_node_children(node.children)
	end
end

---@param comments BitbucketPRCommentEntry[]|nil
---@return BitbucketPRCommentTreeNode[]
function M.normalize_comments(comments)
	local entries = {}
	for _, comment in ipairs(comments or {}) do
		if type(comment) == "table" then
			table.insert(entries, comment)
		end
	end

	table.sort(entries, less_by_created)

	---@type table<string, BitbucketPRCommentTreeNode>
	local by_id = {}
	for _, comment in ipairs(entries) do
		by_id[tostring(comment.id or "")] = {
			comment = comment,
			children = {},
		}
	end

	---@type BitbucketPRCommentTreeNode[]
	local roots = {}
	for _, comment in ipairs(entries) do
		local node = by_id[tostring(comment.id or "")]
		local parent_id = tonumber(rawget(comment, "parent_id"))
		if parent_id ~= nil then
			local parent = by_id[tostring(parent_id)]
			if parent ~= nil then
				table.insert(parent.children, node)
			else
				table.insert(roots, node)
			end
		else
			table.insert(roots, node)
		end
	end

	sort_node_children(roots)
	return roots
end

return M
