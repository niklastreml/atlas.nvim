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
---@field manage_templates? AtlasKeymapValue
---@field refresh_issue? AtlasKeymapValue
---@field refresh_view? AtlasKeymapValue
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
---| "jira.manage_templates"
---| "jira.refresh_issue"
---| "jira.refresh_view"
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
---@return AtlasKeymapValue
local function from_config(action_id)
	local group, key = tostring(action_id):match("^([^.]+)%.([^.]+)$")
	if group == nil or key == nil then
		return nil
	end

	local keymaps = require("atlas.config").options.keymaps
	if type(keymaps) ~= "table" then
		return nil
	end

	local section = keymaps[group]
	if type(section) ~= "table" then
		return nil
	end

	return section[key]
end

---@param action_id AtlasKeymapActionId|string
---@return string[]|nil
function M.resolve(action_id)
	return normalize(from_config(action_id))
end

---@param action_ids AtlasKeymapActionId[]
---@param builtins string[]
---@return table<string, string[]>
local function conflicts_for(action_ids, builtins)
	---@type table<string, table<string, true>>
	local seen_by_key = {}
	for _, action_id in ipairs(action_ids) do
		local keys = M.resolve(action_id) or {}
		for _, key in ipairs(keys) do
			seen_by_key[key] = seen_by_key[key] or {}
			seen_by_key[key][action_id] = true
		end
	end

	for _, key in ipairs(builtins) do
		seen_by_key[key] = seen_by_key[key] or {}
		seen_by_key[key]["builtin:" .. key] = true
	end

	---@type table<string, string[]>
	local conflicts = {}
	for key, seen in pairs(seen_by_key) do
		local actions = vim.tbl_keys(seen)
		table.sort(actions)
		if #actions > 1 then
			conflicts[key] = actions
		end
	end

	return conflicts
end

---@return table<string, table<string, string[]>>
function M.validate()
	return {
		ui = conflicts_for({
			"ui.help",
			"ui.close",
			"ui.toggle_panel",
			"ui.previous_panel_tab",
			"ui.next_panel_tab",
			"ui.refresh",
		}, { "j", "k", "gg", "G" }),
		jira = conflicts_for({
			"jira.open_actions",
			"jira.search",
			"jira.edit_issue",
			"jira.transition_issue",
			"jira.change_assignee",
			"jira.open_in_browser",
			"jira.create_issue",
			"jira.manage_templates",
			"jira.refresh_issue",
			"jira.refresh_view",
			"jira.toggle_issue_children",
			"jira.show_details",
			"jira.copy_key",
			"jira.copy_url",
		}, { "j", "k", "gg", "G" }),
		bitbucket = conflicts_for({
			"bitbucket.open_actions",
			"bitbucket.search",
			"bitbucket.toggle_repo_panel",
			"bitbucket.checkout_pr",
			"bitbucket.open_diffview",
			"bitbucket.open_in_browser",
			"bitbucket.refresh_pr",
			"bitbucket.refresh_view",
			"bitbucket.show_details",
			"bitbucket.copy_id",
			"bitbucket.copy_url",
			"bitbucket.pr_files_toggle_fold",
			"bitbucket.pr_files_next_hunk",
			"bitbucket.pr_files_previous_hunk",
		}, { "j", "k", "gg", "G" }),
	}
end

return M
