local M = {}
local memory_cache = require("atlas.core.memory_cache")

local CACHE_TTL_SECONDS = 300
local MENTION_MAP_CACHE_KEY = "bitbucket:mentions:map"

---@class BitbucketMentionUser
---@field id string
---@field label string

---@return table<string, string>
local function build_map()
	-- Bitbucket comment/activity text often contains mentions as account IDs
	-- (e.g. "@{<account_id>}"), not display names. We best-effort resolve them
	-- using users known in the current PR detail (author/reviewers/participants).

	local cached_entry = memory_cache.get(MENTION_MAP_CACHE_KEY)
	if type(cached_entry) == "table" and type(cached_entry.value) == "table" then
		if next(cached_entry.value) ~= nil then
			return cached_entry.value
		end
		memory_cache.delete(MENTION_MAP_CACHE_KEY)
	end

	local bitbucket_state = require("atlas.bitbucket.state")
	local overview_state = require("atlas.bitbucket.panel.tabs.pr.overview.state")
	local comments_state = require("atlas.bitbucket.panel.tabs.pr.comments.state")
	local activity_state = require("atlas.bitbucket.panel.tabs.pr.activity.state")
	local detail = overview_state.detail

	local map = {}

	local function add(user)
		if type(user) == "table" and type(user.account_id) == "string" and user.account_id ~= "" then
			map[user.account_id] = user.name or user.nickname or user.account_id
		end
	end

	if type(detail) == "table" then
		add(detail.author)
		for _, r in ipairs(detail.reviewers or {}) do
			add(r)
		end
		for _, p in ipairs(detail.participants or {}) do
			add(p)
		end
	end

	local comments = comments_state.comments
	if comments ~= "loading" and type(comments) == "table" then
		for _, comment in ipairs(comments) do
			add((comment or {}).author)
		end
	end

	local activity = activity_state.activity
	local entries = type(activity) == "table" and activity.entries or {}
	for _, entry in ipairs(entries) do
		add((entry or {}).actor)
	end

	for _, group in ipairs(bitbucket_state.repos or {}) do
		for _, pr in ipairs((group or {}).prs or {}) do
			add((pr or {}).author)
		end
	end

	if next(map) ~= nil then
		memory_cache.set(MENTION_MAP_CACHE_KEY, map, CACHE_TTL_SECONDS)
	end
	return map
end

---@param mention_map table<string, string>
---@return BitbucketMentionUser[]
local function to_mentions(mention_map)
	---@type BitbucketMentionUser[]
	local users = {}
	for id, label in pairs(mention_map or {}) do
		local user_id = tostring(id or "")
		local user_label = vim.trim(tostring(label or ""))
		if user_id ~= "" and user_label ~= "" then
			table.insert(users, { id = user_id, label = user_label })
		end
	end

	table.sort(users, function(a, b)
		return tostring(a.label or ""):lower() < tostring(b.label or ""):lower()
	end)

	return users
end

---@param text string
---@return string
function M.resolve(text)
	local raw = tostring(text or "")
	local mention_map = build_map()

	if raw:find("@{", 1, true) ~= nil then
		return (
			raw:gsub("@{([^}]+)}", function(id)
				local name = mention_map[id]
				if name and name ~= "" then
					return "@" .. name
				end
				return "@{" .. id .. "}"
			end)
		)
	end

	local name = mention_map[raw]
	if name and name ~= "" then
		return tostring(name)
	end

	return raw
end

---@return AtlasMarkdownCompletionProvider
function M.build_completion()
	return {
		trigger = "@",
		find_start = function(before)
			local start_after_at = tostring(before or ""):match(".*@()[-%w_]*$")
			if start_after_at == nil then
				return nil
			end
			return start_after_at - 1
		end,
		complete = function(base)
			local users = to_mentions(build_map())
			local query = vim.trim(tostring(base or "")):lower()
			local matches = {}
			for _, user in ipairs(users) do
				local id = tostring(user.id or "")
				local label = tostring(user.label or "")
				if id ~= "" and label ~= "" and (query == "" or label:lower():find(query, 1, true) == 1) then
					table.insert(matches, {
						word = "{" .. id .. "}",
						abbr = label,
						menu = "mention",
					})
				end
			end
			table.sort(matches, function(a, b)
				return tostring(a.abbr or "") < tostring(b.abbr or "")
			end)
			return matches
		end,
	}
end

return M
