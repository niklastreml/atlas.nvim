local M = {}

---@param value any
---@return boolean
local function is_valid(value)
	return value ~= nil and type(value) ~= "userdata"
end

---@param obj table|nil
---@param key string
---@param subkey string|nil
---@return any
local function safe_get(obj, key, subkey)
	if not is_valid(obj) then
		return nil
	end
	local val = obj[key]
	if subkey then
		if not is_valid(val) then
			return nil
		end
		return val[subkey]
	end
	return val
end

---@param raw_status table|nil
---@return string, string, string|nil
local function extract_status(raw_status)
	if not is_valid(raw_status) then
		return "Unknown", "Unknown", nil
	end

	local name = raw_status.name or "Unknown"
	local category = "Unknown"
	local color = nil

	local cat = safe_get(raw_status, "statusCategory")
	if is_valid(cat) then
		category = cat.name or "Unknown"
		color = cat.colorName
	end

	return name, category, color
end

---@param raw_parent table|nil
---@return JiraIssue|nil
local function extract_parent(raw_parent)
	if not is_valid(raw_parent) or not raw_parent.key then
		return nil
	end

	local pf = raw_parent.fields or {}
	local status, status_category, status_color = extract_status(safe_get(pf, "status"))

	return {
		key = tostring(raw_parent.key),
		summary = tostring(pf.summary or ""),
		status = status,
		status_category = status_category,
		status_color = status_color,
		type = safe_get(pf, "issuetype", "name") or "Epic",
		priority = safe_get(pf, "priority", "name") or "None",
		assignee = safe_get(pf, "assignee", "displayName") or "Unassigned",
		reporter = safe_get(pf, "reporter", "displayName") or "Unknown",
		duedate = nil,
		subtask = false,
		parent = nil,
	}
end

---@param raw table
---@return JiraIssue
function M.normalize_issue(raw)
	local fields = raw.fields or {}
	local status, status_category, status_color = extract_status(safe_get(fields, "status"))

	return {
		key = tostring(raw.key or ""),
		summary = tostring(fields.summary or ""),
		status = status,
		status_category = status_category,
		status_color = status_color,
		type = safe_get(fields, "issuetype", "name") or "Task",
		priority = safe_get(fields, "priority", "name") or "None",
		assignee = safe_get(fields, "assignee", "displayName") or "Unassigned",
		reporter = safe_get(fields, "reporter", "displayName") or "Unknown",
		duedate = fields.duedate,
		subtask = safe_get(fields, "issuetype", "subtask") == true,
		parent = extract_parent(safe_get(fields, "parent")),
	}
end

---@param raw_issues table[]
---@return JiraIssue[]
function M.normalize_issues(raw_issues)
	local out = {}
	for _, raw in ipairs(raw_issues or {}) do
		table.insert(out, M.normalize_issue(raw))
	end
	return out
end

---@param issues JiraIssue[]
---@return JiraIssue[]
function M.build_issue_tree(issues)
	local by_key = {}
	for _, issue in ipairs(issues) do
		issue.children = {}
		by_key[issue.key] = issue
	end

	for _, issue in ipairs(issues) do
		local parent = issue.parent
		if parent and not by_key[parent.key] then
			parent.children = {}
			by_key[parent.key] = parent
		end
	end

	local roots = {}
	for _, issue in ipairs(issues) do
		if issue.parent and by_key[issue.parent.key] then
			table.insert(by_key[issue.parent.key].children, issue)
		else
			table.insert(roots, issue)
		end
	end

	local seen_roots = {}
	for _, r in ipairs(roots) do
		seen_roots[r.key] = true
	end
	for _, issue in ipairs(issues) do
		if issue.parent and by_key[issue.parent.key] then
			local pkey = issue.parent.key
			if not seen_roots[pkey] and by_key[pkey].children and #by_key[pkey].children > 0 then
				table.insert(roots, by_key[pkey])
				seen_roots[pkey] = true
			end
		end
	end

	return roots
end

function M.normalize_comments(raw) end
function M.normalize_transitions(raw) end
function M.normalize_worklogs(raw) end

return M
