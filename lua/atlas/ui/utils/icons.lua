local M = {}

local ICONS = {
	fallback = "•",
	general = {
		entity = {
			refresh = "󰑐",
			overview = "󰈙",
			comment = "󰍩",
			created = "󰃭",
			updated = "󰥔",
			success = "",
			warning = "",
			info = "",
			error = "",
			pending = "",
			branch = "",
			user = "",
		},
	},
	bitbucket = {
		provider = "",
		entity = {
			repo = "",
			pr = "",
			comments = "󰅺",
			tasks = "󰄱",
			check = "",
			commit = "󰜘",
			files = "󰈔",
			activity = "󱐋",
			tag = "",
			author = "",
		},
		status = {
			successful = "",
			failed = "",
			inprogress = "󰦖",
			stopped = "",
			unknown = "",
		},
	},
	jira = {
		provider = "󰌃",
		entity = {
			reply = "",
			edit = "",
			delete = "󰆴",
			story_points = "󰫢",
			project = "",
		},
		type = {
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
	},
}

---@alias AtlasGeneralIconName
---| "refresh"
---| "overview"
---| "comment"
---| "created"
---| "updated"
---| "success"
---| "warning"
---| "info"
---| "error"
---| "pending"
---| "branch"
---| "user"

---@param name AtlasGeneralIconName|nil
function M.entity(name)
	return ICONS.general.entity[name] or ICONS.fallback
end

---@alias BitbucketIconName
---| "bitbucket.provider"
---| "bitbucket.entity.refresh"
---| "bitbucket.entity.overview"
---| "bitbucket.entity.comment"
---| "bitbucket.entity.created"
---| "bitbucket.entity.updated"
---| "bitbucket.entity.success"
---| "bitbucket.entity.warning"
---| "bitbucket.entity.info"
---| "bitbucket.entity.error"
---| "bitbucket.entity.pending"
---| "bitbucket.entity.branch"
---| "bitbucket.entity.user"
---| "bitbucket.entity.repo"
---| "bitbucket.entity.pr"
---| "bitbucket.entity.comments"
---| "bitbucket.entity.tasks"
---| "bitbucket.entity.commit"
---| "bitbucket.entity.files"
---| "bitbucket.entity.activity"
---| "bitbucket.entity.tag"
---| "bitbucket.entity.author"
---| "bitbucket.status.successful"
---| "bitbucket.status.failed"
---| "bitbucket.status.inprogress"
---| "bitbucket.status.stopped"
---| "bitbucket.status.unknown"
---| "repo"
---| "pr"
---| "comments"
---| "tasks"
---| "commit"
---| "files"
---| "activity"
---| "tag"
---| "author"
---| "successful"
---| "failed"
---| "inprogress"
---| "stopped"
---| "unknown"

---@param name BitbucketIconName|string|nil
function M.bitbucket_icon(name)
	local key = tostring(name or ""):lower()
	if key == "" then
		return ICONS.fallback
	end

	if key == "bitbucket.provider" then
		return ICONS.bitbucket.provider or ICONS.fallback
	end

	local entity_prefix = "bitbucket.entity."
	if key:sub(1, #entity_prefix) == entity_prefix then
		local entity_name = key:sub(#entity_prefix + 1)
		return ICONS.bitbucket.entity[entity_name] or ICONS.general.entity[entity_name] or ICONS.fallback
	end

	local status_prefix = "bitbucket.status."
	if key:sub(1, #status_prefix) == status_prefix then
		local status_name = key:sub(#status_prefix + 1):gsub("[-%s_]", "")
		return ICONS.bitbucket.status[status_name] or ICONS.bitbucket.status.unknown
	end

	local lower = key:gsub("[-%s_]", "")
	return ICONS.bitbucket.entity[lower]
		or ICONS.bitbucket.status[lower]
		or ICONS.general.entity[lower]
		or ICONS.fallback
end

---@alias JiraIconName
---| "jira.provider"
---| "jira.entity.refresh"
---| "jira.entity.overview"
---| "jira.entity.comment"
---| "jira.entity.created"
---| "jira.entity.updated"
---| "jira.entity.success"
---| "jira.entity.warning"
---| "jira.entity.info"
---| "jira.entity.error"
---| "jira.entity.pending"
---| "jira.entity.branch"
---| "jira.entity.user"
---| "jira.entity.reply"
---| "jira.entity.edit"
---| "jira.entity.delete"
---| "jira.entity.story_points"
---| "jira.entity.project"
---| "jira.type.epic"
---| "jira.type.story"
---| "jira.type.task"
---| "jira.type.bug"
---| "jira.type.subtask"
---| "jira.type.highest"
---| "jira.type.blocker"
---| "jira.type.high"
---| "jira.type.medium"
---| "jira.type.low"
---| "jira.type.lowest"
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
	local key = tostring(name or ""):lower()
	if key == "" then
		return ICONS.fallback
	end

	if key == "jira.provider" then
		return ICONS.jira.provider or ICONS.fallback
	end

	local entity_prefix = "jira.entity."
	if key:sub(1, #entity_prefix) == entity_prefix then
		local entity_name = key:sub(#entity_prefix + 1)
		return ICONS.jira.entity[entity_name] or ICONS.general.entity[entity_name] or ICONS.fallback
	end

	local type_prefix = "jira.type."
	if key:sub(1, #type_prefix) == type_prefix then
		local type_name = key:sub(#type_prefix + 1)
		return ICONS.jira.type[type_name] or ICONS.fallback
	end

	local lower = key:gsub("[-%s]", "")
	return ICONS.jira.type[lower] or ICONS.jira.entity[lower] or ICONS.general.entity[lower] or ICONS.fallback
end

function M.fallback()
	return ICONS.fallback
end

return M
