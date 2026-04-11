---@class AtlasJiraPanelSelection
---@field provider "jira"
---@field item JiraIssue|nil

---@class AtlasBitbucketPanelSelection
---@field provider "bitbucket"
---@field panel_type "pr"|"repo"
---@field item BitbucketPR|BitbucketRepository|nil

---@alias AtlasPanelSelection AtlasJiraPanelSelection|AtlasBitbucketPanelSelection

local M = {
	open = false,
	---@type "bitbucket"|"jira"|nil
	active_provider = nil,
	---@type JiraIssue|BitbucketPR|BitbucketRepository|nil
	selected_item = nil,
}

---@param selection AtlasPanelSelection|nil
function M.set_selection(selection)
	M.active_provider = selection and selection.provider or nil
	M.selected_item = selection and selection.item or nil
end

function M.clear_selection()
	M.active_provider = nil
	M.selected_item = nil
end

return M
