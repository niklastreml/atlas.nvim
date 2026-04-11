local M = {}

---@return table<string, string>
local function build_map()
	local overview_state = require("atlas.bitbucket.panel.tabs.pr.overview.state")
	local detail = overview_state.detail
	if type(detail) ~= "table" then
		return {}
	end

	local map = {}

	local function add(user)
		if type(user) == "table" and type(user.account_id) == "string" and user.account_id ~= "" then
			map[user.account_id] = user.name or user.nickname or user.account_id
		end
	end

	add(detail.author)
	for _, r in ipairs(detail.reviewers or {}) do
		add(r)
	end
	for _, p in ipairs(detail.participants or {}) do
		add(p)
	end

	return map
end

---@param text string
---@param mention_map table<string, string>
---@return string
local function resolve(text, mention_map)
	return (
		text:gsub("@{([^}]+)}", function(id)
			local name = mention_map[id]
			if name and name ~= "" then
				return "@" .. name
			end
			return "@{" .. id .. "}"
		end)
	)
end

---@param statuses BitbucketPRStatuses|nil
---@return "successful"|"failed"|"inprogress"|"stopped"|"unknown"
local function aggregate_status(statuses)
	if type(statuses) ~= "table" or type(statuses.entries) ~= "table" then
		return "unknown"
	end

	local has_success = false
	local has_stopped = false
	for _, entry in ipairs(statuses.entries) do
		local s = tostring(entry.state or "UNKNOWN")
		if s == "FAILED" then
			return "failed"
		end
		if s == "INPROGRESS" then
			return "inprogress"
		end
		if s == "STOPPED" then
			has_stopped = true
		elseif s == "SUCCESSFUL" then
			has_success = true
		end
	end

	if has_stopped then
		return "stopped"
	end
	if has_success then
		return "successful"
	end
	return "unknown"
end

---@param status string|nil
---@return string
local function status_label(status)
	local s = tostring(status or ""):lower()
	if s == "" then
		return "Unknown"
	end
	return s:sub(1, 1):upper() .. s:sub(2)
end

-- Bitbucket comment/activity text often contains mentions as account IDs
-- (e.g. "@{<account_id>}"), not display names. We best-effort resolve them
-- using users known in the current PR detail (author/reviewers/participants).
M.mentions = {
	build_map = build_map,
	resolve = resolve,
}

M.statuses = {
	aggregate = aggregate_status,
	label = status_label,
}

return M
