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
		story_points = "󰫢",
		updated = "󰥔",
		success = "",
		warning = "",
		info = "",
		error = "",
		pending = "",
		branch = "",
		tag = "󰓹",
		author = "",
		user = "",
	},
	jira_type = {
		epic = "󰛨",
		story = "󰃀",
		task = "",
		bug = "",
		subtask = "󰩊",

		highest = "",
		blocker = "",
		high = "",
		medium = "",
		low = "",
		lowest = "",
	},
	fallback = "•",
}

---@param name "jira" | "bitbucket"
function M.provider(name)
	return ICONS.provider[name] or ICONS.fallback
end

---@param name "repo"|"refresh"|"pr"|"comments"|"tasks"|"created"|"story_points"|"updated"|"commit"|"overview"|"files"|"activity"|"comment"|"success"|"warning"|"info"|"error"|"pending"|"branch"|"tag"|"author"|"user"
function M.entity(name)
	return ICONS.entity[name] or ICONS.fallback
end

---@alias JiraIconName
---| "epic"
---| "story"
---| "task"
---| "bug"
---| "subtask"
---| "highest"
---| "blocker"
---| "high"
---| "medium"
---| "low"
---| "lowest"

---@param name JiraIconName|string|nil
function M.jira_icon(name)
	local lower = (name or ""):lower():gsub("[-%s]", "")
	return ICONS.jira_type[lower] or ICONS.fallback
end

function M.fallback()
	return ICONS.fallback
end

return M
