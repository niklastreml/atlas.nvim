local M = {}

local ICONS = {
	fallback = "•",

	general = {
		refresh = "󰑐",
		overview = "󰈙",
		comment = "󰍩",
		created = "󰃭",
		updated = "󰥔",
		user = "",
		reply = "",
		edit = "",
		delete = "󰆴",
		success = "",
		waring = "",
		error = "",
		info = "",
	},

	pulls = {
		repo = "",
		pr = "",
		comments = "󰅺",
		tasks = "󰄱",
		check = "",
		commit = "󰜘",
		files = "󰈔",
		activity = "󱐋",
		tag = "",
		branch = "",

		status = {
			successful = "",
			failed = "",
			inprogress = "󰦖",
			stopped = "",
			unknown = "",
		},

		providers = {
			bitbucket = {
				provider = "",
			},
			mock = {
				provider = "󰙨",
			},
		},
	},

	issues = {
		providers = {
			jira = {
				provider = "󰌃",
			},
		},
	},
}

--------------------------------------------------------------------------------
-- General
--------------------------------------------------------------------------------

---@param name string
---@return string
function M.general(name)
	return ICONS.general[name] or ICONS.fallback
end

--------------------------------------------------------------------------------
-- Pulls
--------------------------------------------------------------------------------

---@param name string
---@return string
function M.pulls(name)
	local pull_icon = ICONS.pulls[name]
	if type(pull_icon) == "string" then
		return pull_icon
	end

	local general_icon = ICONS.general[name]
	if type(general_icon) == "string" then
		return general_icon
	end

	return ICONS.fallback
end

---@param status string
---@return string
function M.pulls_status(status)
	local tbl = ICONS.pulls.status
	if tbl and tbl[status] then
		return tbl[status]
	end
	return ICONS.fallback
end

---@param provider_id AtlasPullsProviderId
---@param name string
---@return string
function M.pulls_provider(provider_id, name)
	local provider = (ICONS.pulls.providers or {})[provider_id]
	if provider and provider[name] then
		return provider[name]
	end
	return M.pulls(name)
end

--------------------------------------------------------------------------------
-- Issues
--------------------------------------------------------------------------------

---@param name string
---@return string
function M.issues(name)
	local issue_icon = ICONS.issues[name]
	if type(issue_icon) == "string" then
		return issue_icon
	end

	local general_icon = ICONS.general[name]
	if type(general_icon) == "string" then
		return general_icon
	end

	return ICONS.fallback
end

---@param provider_id AtlasIssuesProviderId
---@param name string
---@return string
function M.issues_provider(provider_id, name)
	local provider = (ICONS.issues.providers or {})[provider_id]
	if provider and provider[name] then
		return provider[name]
	end
	return M.issues(name)
end

--------------------------------------------------------------------------------
-- Fallback
--------------------------------------------------------------------------------

---@return string
function M.fallback()
	return ICONS.fallback
end

return M
