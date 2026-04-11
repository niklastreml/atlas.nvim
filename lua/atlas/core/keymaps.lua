local M = {}

---@class AtlasUIKeymaps
---@field help? AtlasKeymapValue
---@field close? AtlasKeymapValue
---@field toggle_panel? AtlasKeymapValue
---@field previous_panel_tab? AtlasKeymapValue
---@field next_panel_tab? AtlasKeymapValue
---@field refresh? AtlasKeymapValue

---@class AtlasJiraKeymaps
---@field open_actions? AtlasKeymapValue
---@field search? AtlasKeymapValue
---@field edit_issue? AtlasKeymapValue
---@field transition_issue? AtlasKeymapValue
---@field change_assignee? AtlasKeymapValue
---@field open_in_browser? AtlasKeymapValue
---@field create_issue? AtlasKeymapValue
---@field refresh_issue? AtlasKeymapValue
---@field refresh_view? AtlasKeymapValue
---@field refresh_tab? AtlasKeymapValue
---@field toggle_issue_children? AtlasKeymapValue
---@field show_details? AtlasKeymapValue
---@field copy_key? AtlasKeymapValue
---@field copy_url? AtlasKeymapValue

---@class AtlasBitbucketKeymaps
---@field open_actions? AtlasKeymapValue
---@field search? AtlasKeymapValue
---@field toggle_repo_panel? AtlasKeymapValue
---@field checkout_pr? AtlasKeymapValue
---@field open_diffview? AtlasKeymapValue
---@field open_in_browser? AtlasKeymapValue
---@field refresh_pr? AtlasKeymapValue
---@field refresh_view? AtlasKeymapValue
---@field refresh_tab? AtlasKeymapValue
---@field show_details? AtlasKeymapValue
---@field copy_id? AtlasKeymapValue
---@field copy_url? AtlasKeymapValue
---@field pr_files_toggle_fold? AtlasKeymapValue
---@field pr_files_next_hunk? AtlasKeymapValue
---@field pr_files_previous_hunk? AtlasKeymapValue

---@alias AtlasKeymapActionId
---| "ui.help"
---| "ui.close"
---| "ui.toggle_panel"
---| "ui.previous_panel_tab"
---| "ui.next_panel_tab"
---| "ui.refresh"
---| "jira.open_actions"
---| "jira.search"
---| "jira.edit_issue"
---| "jira.transition_issue"
---| "jira.change_assignee"
---| "jira.open_in_browser"
---| "jira.create_issue"
---| "jira.refresh_issue"
---| "jira.refresh_view"
---| "jira.refresh_tab"
---| "jira.toggle_issue_children"
---| "jira.show_details"
---| "jira.copy_key"
---| "jira.copy_url"
---| "bitbucket.open_actions"
---| "bitbucket.search"
---| "bitbucket.toggle_repo_panel"
---| "bitbucket.checkout_pr"
---| "bitbucket.open_diffview"
---| "bitbucket.open_in_browser"
---| "bitbucket.refresh_pr"
---| "bitbucket.refresh_view"
---| "bitbucket.refresh_tab"
---| "bitbucket.show_details"
---| "bitbucket.copy_id"
---| "bitbucket.copy_url"
---| "bitbucket.pr_files_toggle_fold"
---| "bitbucket.pr_files_next_hunk"
---| "bitbucket.pr_files_previous_hunk"

---@alias AtlasKeymapValue string|string[]|false|nil

---@param value AtlasKeymapValue
---@return string[]|nil
local function normalize(value)
	if value == false or value == nil then
		return nil
	end

	if type(value) == "string" then
		if value == "" then
			return nil
		end
		return { value }
	end

	if type(value) ~= "table" then
		return nil
	end

	local keys = {}
	for _, key in ipairs(value) do
		if type(key) == "string" and key ~= "" then
			table.insert(keys, key)
		end
	end

	if #keys == 0 then
		return nil
	end

	return keys
end

---@param action_id AtlasKeymapActionId|string
---@return string[]
local function split_path(action_id)
	local parts = {}
	for part in string.gmatch(action_id, "[^%.]+") do
		table.insert(parts, part)
	end
	return parts
end

---@param action_id AtlasKeymapActionId|string
---@return AtlasKeymapValue
local function from_config(action_id)
	local path = split_path(action_id)
	local unpack_fn = table.unpack or unpack
	local tbl_get = vim.tbl_get
	if type(tbl_get) == "function" then
		return tbl_get(require("atlas.config").options, "keymaps", unpack_fn(path))
	end

	---@type AtlasKeymapsConfig|nil
	local node = require("atlas.config").options.keymaps
	for _, part in ipairs(path) do
		if type(node) ~= "table" then
			return nil
		end
		node = node[part]
	end

	return node
end

---@param action_id AtlasKeymapActionId|string
---@return string[]|nil
function M.resolve(action_id)
	return normalize(from_config(action_id))
end

return M
