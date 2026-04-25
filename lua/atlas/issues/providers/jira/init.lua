local icons = require("atlas.ui.shared.icons")

---@class JiraProvider : IssuesProvider
local M = {
	id = "jira",
	name = "Jira",
	icon = icons.issues_provider("jira", "provider"),
	hl_group = "AtlasJiraTheme",
	panel = require("atlas.issues.providers.jira.ui.panel"),
}

function M.setup()
	require("atlas.issues.providers.jira.highlights").setup()
end

function M.on_refresh()
	local service = require("atlas.issues.providers.jira.api.service")
	service.clear_memory_cache()
end

---@param issue Issue
---@param is_child boolean
---@return table
function M.format_row(issue, is_child)
	return require("atlas.issues.providers.jira.ui.renderer").format_row(issue, is_child)
end

---@param row table
---@param col table
---@param ctx { text: string, padded: string, width: integer }
---@return table[]|nil
function M.cell_hl(row, col, ctx)
	return require("atlas.issues.providers.jira.ui.renderer").cell_hl(row, col, ctx)
end

---@param on_done fun(user: IssueUser|nil, err: string|nil)
function M.fetch_user(on_done)
	local users_api = require("atlas.issues.providers.jira.api.users")
	users_api.get_myself(on_done)
end

---@param view IssuesViewConfig
---@param opts IssuesFetchOpts
---@param on_done fun(issues: Issue[], next_page_token: string|nil, is_last: boolean, err: string|nil)
---@return { cancel: fun() }|nil
function M.fetch_issues(view, opts, on_done)
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
	local issues_api = require("atlas.issues.providers.jira.api.issues")
	return issues_api.get_issue(issue_key, on_done)
end

---@param issue_key string
---@param opts IssuesFetchOpts|nil
---@param on_done fun(raw: any, err: string|nil)
---@return { cancel: fun() }|nil
function M.fetch_description(issue_key, opts, on_done)
	local issues_api = require("atlas.issues.providers.jira.api.issues")
	return issues_api.get_issue_description(issue_key, on_done, opts)
end

---@param issue_key string
---@param opts IssuesFetchOpts|nil
---@param on_done fun(comments: IssueComment[]|nil, err: string|nil)
---@return { cancel: fun() }|nil
function M.fetch_comments(issue_key, opts, on_done)
	local comments_api = require("atlas.issues.providers.jira.api.comments")
	local COMMENTS_PAGE_SIZE = 100

	return comments_api.get_comments_page(issue_key, 0, COMMENTS_PAGE_SIZE, on_done, {
		force_load = opts and opts.force_load or false,
	})
end

---@param issue_key string
---@param opts IssuesFetchOpts|nil
---@param on_done fun(entries: table[]|nil, err: string|nil)
---@return { cancel: fun() }|nil
function M.fetch_history(issue_key, opts, on_done)
	local issues_api = require("atlas.issues.providers.jira.api.issues")
	return issues_api.get_issue_history_page(issue_key, 0, 100, function(page, err)
		if err or not page then
			on_done(nil, err)
			return
		end
		on_done(page.values or {}, nil)
	end, {
		force_load = opts and opts.force_load or false,
	})
end

---@param action_id string
---@param ctx table
---@param on_done fun(result: table|nil, err: string|nil)
function M.run_action(action_id, ctx, on_done)
	local jira_actions = require("atlas.issues.providers.jira.actions")
	jira_actions.run(action_id, ctx, on_done)
end

---@param issue Issue|nil
---@param source "main"|"panel"|nil
---@param on_done fun(result: table|nil, err: string|nil)
function M.open_actions(issue, source, on_done)
	local jira_actions = require("atlas.issues.providers.jira.actions")
	jira_actions.open({ issue = issue, source = source }, on_done)
end

---@param on_done fun(result: table|nil, err: string|nil)|nil
function M.search(on_done)
	local jira_actions = require("atlas.issues.providers.jira.actions")
	jira_actions.run("search_query_issue", { issue = nil, source = "main" }, function(result, err)
		if on_done ~= nil then
			on_done(result, err)
		end
	end)
end

---@return AtlasJiraViewConfig[]
function M.views()
	local cfg = require("atlas.issues.providers.jira.api.service").jira_config()
	local views = cfg.views or nil
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
