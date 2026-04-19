local icons = require("atlas.ui.shared.icons")
local config = require("atlas.config")

---@class JiraProvider : IssuesProvider
local M = {
	id = "jira",
	name = "Jira",
	icon = icons.issues_provider("jira", "provider"),
	hl_group = "AtlasJiraTheme",
}

---@return AtlasJiraIssuesConfig|nil
local function jira_config()
	return config.options and config.options.issues and config.options.issues.jira or nil
end

local function ensure_legacy_jira_config_alias()
	if config.options == nil then
		return
	end

	if config.options.jira ~= nil then
		return
	end

	local cfg = jira_config()
	if cfg ~= nil then
		config.options.jira = cfg
	end
end

local function ensure_legacy_module_aliases()
	package.preload["atlas.jira.api.service"] = function()
		return require("atlas.issues.providers.jira.api.service")
	end
	package.preload["atlas.jira.api.normalizer"] = function()
		return require("atlas.issues.providers.jira.api.normalizer")
	end
	package.preload["atlas.jira.api.issues"] = function()
		return require("atlas.issues.providers.jira.api.issues")
	end
	package.preload["atlas.jira.api.users"] = function()
		return require("atlas.issues.providers.jira.api.users")
	end
	package.preload["atlas.jira.converted.adf"] = function()
		return require("atlas.issues.providers.jira.converted.adf")
	end
	package.preload["atlas.jira.actions"] = function()
		return require("atlas.issues.providers.jira.actions")
	end
	package.preload["atlas.jira.actions.registry"] = function()
		return require("atlas.issues.providers.jira.actions.registry")
	end
end

function M.setup()
	ensure_legacy_jira_config_alias()
	ensure_legacy_module_aliases()
	require("atlas.issues.providers.jira.highlights").setup()
end

---@param on_done fun(user: IssueUser|nil, err: string|nil)
function M.fetch_user(on_done)
	ensure_legacy_jira_config_alias()
	ensure_legacy_module_aliases()
	local users_api = require("atlas.issues.providers.jira.api.users")
	users_api.get_myself(on_done)
end

---@param view IssuesViewConfig
---@param opts IssuesFetchOpts
---@param on_done fun(issues: Issue[], next_page_token: string|nil, is_last: boolean, err: string|nil)
---@return { cancel: fun() }|nil
function M.fetch_issues(view, opts, on_done)
	ensure_legacy_jira_config_alias()
	ensure_legacy_module_aliases()
	local issues_api = require("atlas.issues.providers.jira.api.issues")
	---@cast view AtlasJiraViewConfig

	local jql = tostring(view and view.jql or "")
	if jql == "" then
		on_done({}, nil, true, "Missing Jira view JQL")
		return nil
	end

	return issues_api.search_issues(jql, function(page, err)
		if err or page == nil then
			on_done({}, nil, true, err or "Failed to fetch issues")
			return
		end

		on_done(page.issues or {}, page.nextPageToken, page.isLast == true, nil)
	end, {
		force_load = opts and opts.force_load == true or false,
		next_page_token = opts and opts.next_page_token or nil,
		max_results = opts and opts.max_results or nil,
	})
end

---@param issue_key string
---@param opts IssuesFetchOpts|nil
---@param on_done fun(issue: Issue|nil, err: string|nil)
---@return { cancel: fun() }|nil
function M.fetch_issue(issue_key, opts, on_done)
	ensure_legacy_jira_config_alias()
	ensure_legacy_module_aliases()
	local issues_api = require("atlas.issues.providers.jira.api.issues")
	return issues_api.get_issue(issue_key, on_done)
end

---@param action_id string
---@param ctx table
---@param on_done fun(result: table|nil, err: string|nil)
function M.run_action(action_id, ctx, on_done)
	ensure_legacy_jira_config_alias()
	ensure_legacy_module_aliases()
	local jira_actions = require("atlas.issues.providers.jira.actions")
	jira_actions.run(action_id, ctx, on_done)
end

---@param issue Issue|nil
---@param source "main"|"panel"|nil
---@param on_done fun(result: table|nil, err: string|nil)
function M.open_actions(issue, source, on_done)
	ensure_legacy_jira_config_alias()
	ensure_legacy_module_aliases()
	local jira_actions = require("atlas.issues.providers.jira.actions")
	jira_actions.open({ issue = issue, source = source }, on_done)
end

---@param on_done fun(result: table|nil, err: string|nil)|nil
function M.search(on_done)
	ensure_legacy_jira_config_alias()
	ensure_legacy_module_aliases()
	local jira_actions = require("atlas.issues.providers.jira.actions")
	jira_actions.run("search_query_issue", { issue = nil, source = "main" }, function(result, err)
		if on_done ~= nil then
			on_done(result, err)
		end
	end)
end

---@return AtlasJiraViewConfig[]
function M.views()
	ensure_legacy_jira_config_alias()
	local cfg = jira_config()
	local views = cfg and cfg.views or nil
	if views ~= nil and #views > 0 then
		return views
	end

	return {
		{
			name = "Issues",
			key = "1",
			jql = "assignee = currentUser() AND resolution = Unresolved ORDER BY updated DESC",
		},
	}
end

return M
