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

-- Bitbucket comment/activity text often contains mentions as account IDs
-- (e.g. "@{<account_id>}"), not display names. We best-effort resolve them
-- using users known in the current PR detail (author/reviewers/participants).
M.mentions = {
	build_map = build_map,
	resolve = resolve,
}

return M
