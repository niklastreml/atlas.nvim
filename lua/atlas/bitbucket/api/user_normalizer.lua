local M = {}

---@param v any
---@return table|nil
local function as_table(v)
	if type(v) == "table" then
		return v
	end
	return nil
end

---@param raw_user table|nil
---@return BitbucketCurrentUser
function M.current_user(raw_user)
	local user = as_table(raw_user) or {}

	return {
		name = user.display_name,
		account_id = user.account_id ~= nil and tostring(user.account_id) or nil,
		nickname = user.nickname ~= nil and tostring(user.nickname) or nil,
		display_name = user.display_name,
		username = user.username ~= nil and tostring(user.username) or nil,
		uuid = user.uuid ~= nil and tostring(user.uuid) or nil,
		created_on = user.created_on ~= nil and tostring(user.created_on) or nil,
	}
end

---@param result table|nil
---@return BitbucketWorkspace[]
function M.workspaces(result)
	local payload = as_table(result) or {}
	local out = {}
	for _, item in ipairs(payload.values or {}) do
		local entry = as_table(item) or {}
		local workspace = as_table(entry.workspace) or {}
		local links = as_table(workspace.links) or {}
		local self_link = as_table(links.self) or {}

		table.insert(out, {
			administrator = entry.administrator == true,
			slug = tostring(workspace.slug or ""),
			uuid = tostring(workspace.uuid or ""),
			links_self = self_link.href ~= nil and tostring(self_link.href) or nil,
		})
	end
	return out
end

return M
