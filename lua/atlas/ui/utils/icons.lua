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
		reply = "",
		edit = "",
		delete = "󰆴",
		created = "󰃭",
		story_points = "󰫢",
		updated = "󰥔",
		success = "",
		warning = "",
		info = "",
		error = "",
		pending = "",
		branch = "",
		tag = "",
		author = "",
		user = "",
		project = "",
	},
	jira_type = {
		epic = "",
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
	bitbucket_status = {
		successful = "",
		failed = "",
		inprogress = "",
		stopped = "",
		unknown = "",
	},
	fallback = "•",
}

---@param name "jira" | "bitbucket"
function M.provider(name)
	return ICONS.provider[name] or ICONS.fallback
end

---@param name "repo"|"refresh"|"pr"|"comments"|"tasks"|"created"|"story_points"|"updated"|"commit"|"overview"|"files"|"activity"|"comment"|"reply"|"edit"|"delete"|"success"|"warning"|"info"|"error"|"pending"|"branch"|"tag"|"author"|"user"|"project"
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

---@param name "SUCCESSFUL"|"FAILED"|"INPROGRESS"|"STOPPED"|"unknown"|string|nil
function M.bitbucket_status(name)
	local key = tostring(name or ""):lower():gsub("[-%s_]", "")
	return ICONS.bitbucket_status[key] or ICONS.bitbucket_status.unknown
end

function M.fallback()
	return ICONS.fallback
end

return M
