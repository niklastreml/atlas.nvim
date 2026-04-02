local M = {}

local highlights = require("atlas.ui.highlights")

---@param issue_type string|nil
---@return string
function M.issue_type_hl(issue_type)
	local lower = tostring(issue_type or ""):lower()
	if lower == "bug" then
		return "AtlasLogError"
	end
	if lower == "story" then
		return "AtlasTextPositive"
	end
	if lower == "epic" then
		return "AtlasJiraEpic"
	end
	if lower == "task" or lower == "sub-task" or lower == "subtask" then
		return "AtlasLogInfo"
	end
	return "AtlasTextMuted"
end

---@return string
function M.issue_title_hl()
	return "AtlasJiraTitle"
end

---@param status_id string|nil
---@return string
function M.status_hl(status_id)
	return highlights.dynamic_for_bg(status_id and ("jira-status:" .. status_id) or nil) or "AtlasTextMuted"
end

---@param priority string|nil
---@return string
function M.priority_hl(priority)
	local lower = tostring(priority or ""):lower()
	if lower == "highest" or lower == "high" or lower == "blocker" then
		return "AtlasLogError"
	end
	if lower == "medium" then
		return "AtlasTextWarning"
	end
	if lower == "low" or lower == "lowest" then
		return "AtlasTextPositive"
	end
	return "AtlasTextMuted"
end

---@param name string|nil
---@return string
function M.person_hl(name)
	if type(name) ~= "string" then
		return "AtlasTextMutedItalic"
	end

	local lower = vim.trim(name):lower()
	if lower == "" or lower == "unassigned" or lower == "none" then
		return "AtlasTextMutedItalic"
	end

	return highlights.dynamic_for(lower) or "AtlasTextMuted"
end

return M
