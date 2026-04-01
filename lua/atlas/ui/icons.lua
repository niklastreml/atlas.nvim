local M = {}

local ICONS = {
	provider = {
		jira = "󰌃",
		bitbucket = "",
	},
	entity = {
		refresh = "󰑐",
		repo = "",
		pr = "",
		comments = "󰅺",
		tasks = "󰄱",
		commit = "󰜘",
		overview = "󰈙",
		files = "󰈔",
		activity = "󱐋",
		comment = "󰍩",
		created = "󰃭",
		updated = "󰥔",
		success = "",
		warning = "",
		info = "",
		error = "",
		pending = "",
		branch = "",
		tag = "󰓹",
		author = "",
	},
	jira_type = {
		epic = "󰛨",
		story = "󰃀",
		task = "󰄵",
		bug = "",
		subtask = "󰩊",
	},
	fallback = "•",
}

---@param name "jira" | "bitbucket"
function M.provider(name)
	return ICONS.provider[name] or ICONS.fallback
end

---@param name "repo"|"refresh"|"pr"|"comments"|"tasks"|"created"|"updated"|"commit"|"overview"|"files"|"activity"|"comment"|"success"|"warning"|"info"|"error"|"pending"|"branch"|"tag"|"author"
function M.entity(name)
	return ICONS.entity[name] or ICONS.fallback
end

---@param name string
function M.jira_type(name)
	local lower = (name or ""):lower():gsub("[-%s]", "")
	return ICONS.jira_type[lower] or ICONS.fallback
end

function M.fallback()
	return ICONS.fallback
end

return M
