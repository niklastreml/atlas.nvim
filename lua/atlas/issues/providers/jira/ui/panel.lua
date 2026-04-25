---@class JiraIssuesProviderPanel : IssuesProviderPanel
local M = {}

local icons = require("atlas.ui.shared.icons")
local utils = require("atlas.ui.shared.utils")

local overview_state = require("atlas.issues.ui.panel.issue.tabs.overview.state")
local comments_state = require("atlas.issues.ui.panel.issue.tabs.comments.state")
local history_state = require("atlas.issues.ui.panel.issue.tabs.history.state")

--------------------------------------------------------------------------------
-- Header rows
--------------------------------------------------------------------------------

---@param issue Issue
---@return IssuesPanelHeaderRow[]
function M.header_rows(issue)
	local rows = {}

	local project_key = issue.project and issue.project.key or nil
	if project_key then
		local config = require("atlas.config")
		local jira_cfg = config.options and config.options.issues and config.options.issues.jira or nil
		local project_config = jira_cfg and jira_cfg.project_config and jira_cfg.project_config[project_key] or nil
		if project_config then
			if overview_state.custom_fields_loading then
				table.insert(rows, {
					k1 = "Fields:",
					v1 = "Loading...",
					v1_hl = "AtlasTextMuted",
					k2 = "",
					v2 = "",
					v2_hl = nil,
				})
			else
				local custom_fields = overview_state.custom_fields or {}
				for _, field in ipairs(custom_fields) do
					if field.display == "table" then
						table.insert(rows, {
							k1 = string.format("%s:", field.name),
							v1 = field.formatted,
							v1_hl = field.hl_group or "Normal",
							k2 = "",
							v2 = "",
							v2_hl = nil,
						})
					end
				end
			end
		end
	end

	return rows
end

--------------------------------------------------------------------------------
-- Chips
--------------------------------------------------------------------------------

---@param issue Issue
---@return IssuesPanelChip[]
function M.chips(issue)
	local chips = {}

	local parent_key = issue.parent and issue.parent.key or nil
	table.insert(chips, {
		label = string.format("%s %s", icons.pulls("branch"), parent_key or "-"),
		hl = parent_key and "AtlasJiraChipParent" or "AtlasTextMuted",
	})

	local sp = issue.story_points
	local sp_text = type(sp) == "number" and tostring(sp) or "-"
	table.insert(chips, {
		label = string.format("%s %s", icons.issues_provider("jira", "provider"), sp_text),
		hl = type(sp) == "number" and "AtlasJiraChipStoryPoints" or "AtlasTextMuted",
	})

	local due = utils.format_date and utils.format_date(issue.duedate) or tostring(issue.duedate or "")
	local due_text = due ~= "" and due or "-"
	table.insert(chips, {
		label = string.format("%s %s", icons.general("created"), due_text),
		hl = due ~= "" and "AtlasJiraChipDueDate" or "AtlasTextMuted",
	})

	if overview_state.custom_fields_loading then
		table.insert(chips, { label = "Loading...", hl = "AtlasTextMuted" })
	else
		local custom_fields = overview_state.custom_fields or {}
		for _, field in ipairs(custom_fields) do
			if field.display == "chip" then
				table.insert(chips, {
					label = field.formatted,
					hl = field.hl_group or "AtlasChipActive",
				})
			end
		end
	end

	return chips
end

---@param raw any
---@return string|nil
function M.convert_description(raw)
	if type(raw) ~= "table" then
		return type(raw) == "string" and raw or nil
	end
	local adf = require("atlas.issues.providers.jira.converted.adf")
	return adf.to_markdown(raw)
end

--------------------------------------------------------------------------------
-- Fetches
--------------------------------------------------------------------------------

---@param issue Issue
---@param refresh fun()
---@param opts { force_load?: boolean }|nil
function M.fetches(issue, refresh, opts)
	local issue_key = tostring(issue.key or "")
	local project_key = issue.project and issue.project.key or nil

	local config = require("atlas.config")
	local jira_cfg = config.options and config.options.issues and config.options.issues.jira or nil
	local project_config = jira_cfg and jira_cfg.project_config and project_key and jira_cfg.project_config[project_key]
		or nil

	if not project_config then
		overview_state.custom_fields = nil
		overview_state.custom_fields_loading = false
		return
	end

	local extra_fields = {}
	for field_id, _ in pairs(project_config) do
		table.insert(extra_fields, field_id)
	end

	if #extra_fields == 0 then
		overview_state.custom_fields = nil
		overview_state.custom_fields_loading = false
		return
	end

	overview_state.custom_fields = nil
	overview_state.custom_fields_loading = true

	local issues_api = require("atlas.issues.providers.jira.api.issues")
	issues_api.get_custom_fields(issue_key, extra_fields, function(values, err)
		overview_state.custom_fields_loading = false

		if err or not values then
			overview_state.custom_fields = nil
			refresh()
			return
		end

		overview_state.custom_fields = {}
		for field_id, field_cfg in pairs(project_config) do
			local raw_value = values[field_id]
			if raw_value ~= nil then
				local format_ok, formatted = pcall(field_cfg.format, raw_value)
				if format_ok and formatted and formatted ~= "" then
					table.insert(overview_state.custom_fields, {
						name = field_cfg.name or field_id,
						formatted = formatted,
						hl_group = field_cfg.hl_group,
						display = field_cfg.display or "table",
					})
				end
			end
		end

		refresh()
	end, { force_load = opts and opts.force_load == true })
end

---@param issue Issue
---@return boolean
function M.is_loading(issue)
	return overview_state.description_loading or comments_state.any_loading() or history_state.any_loading()
end

--------------------------------------------------------------------------------
-- Tabs
--------------------------------------------------------------------------------

---@return IssuesPanelTab[]
function M.tabs()
	return {
		{
			key = "overview",
			label = "Overview",
			icon = icons.general("overview"),
			mod = require("atlas.issues.ui.panel.issue.tabs.overview"),
		},
		{
			key = "comments",
			label = "Comments",
			icon = icons.general("comment"),
			mod = require("atlas.issues.ui.panel.issue.tabs.comments"),
		},
		{
			key = "history",
			label = "History",
			icon = icons.pulls("activity"),
			mod = require("atlas.issues.ui.panel.issue.tabs.history"),
		},
	}
end

return M
