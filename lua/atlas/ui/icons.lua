local M = {}

local ICONS = {
	provider = {
		jira = "",
		bitbucket = "",
		github = "",
	},
	entity = {
		refresh = "󰑐",
		repo = "",
		pr = "",
		commit = "󰜘",
		overview = "󰈙",
		files = "󰈔",
		activity = "󱐋",
		comment = "󰍩",
		success = "",
		warning = "",
		pending = "",
		branch = "",
		author = "",
	},
	fallback = "•",
}

---@param name "jira" | "bitbucket" | "github"
function M.provider(name)
	return ICONS.provider[name] or ICONS.fallback
end

---@param name "repo"|"refresh"|"pr"|"commit"|"overview"|"files"|"activity"|"comment"|"success"|"warning"|"pending"|"branch"|"author"
function M.entity(name)
	return ICONS.entity[name] or ICONS.fallback
end

function M.fallback()
	return ICONS.fallback
end

return M
