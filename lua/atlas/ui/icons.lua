local M = {}

local ICONS = {
	provider = {
		jira = "",
		bitbucket = "",
		github = "",
	},
	action = {
		refresh = "󰑐",
		help = "",
	},
	fallback = "•",
}

---@params name "jira" | "bitbucket" | "github"
function M.provider(name)
	return ICONS.provider[name] or ICONS.fallback
end

---@params name "refresh" | "help"
function M.action(name)
	return ICONS.action[name] or ICONS.fallback
end

function M.fallback()
  return ICONS.fallback
end

return M
