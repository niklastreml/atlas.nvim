local M = {}

local registry = require("atlas.jira.actions.registry")
local logger = require("atlas.core.logger")
local footer = require("atlas.ui.components.footer")

---@alias JiraActionId
---| "transition"
---| "assign"
---| "reporter"
---| "delete_issue"
---| "edit_issue"
---| "search_query_issue"
---| "search_issues"
---| "create_issue"
---| "create_template"
---| "manage_templates"
---| "browse_issue"
---| "copy_issue_key"
---| "copy_issue_url"

---@param action_id JiraActionId|string
---@param ctx JiraActionContext
---@param on_done fun(result: JiraActionResult|nil, err: string|nil)
function M.run(action_id, ctx, on_done)
	local action = registry.find(action_id)
	if action == nil then
		local err = string.format("Unknown action: %s", tostring(action_id))
		logger.logerror("jira.action.unknown", { action_id = tostring(action_id), source = ctx.source })
		on_done(nil, err)
		return
	end

	local available, available_err = action.is_available(ctx)
	if not available then
		local err =
			tostring(available_err or string.format("Action not available: %s", tostring(action.label or action_id)))
		logger.logwarn("jira.action.unavailable", { action_id = tostring(action_id), source = ctx.source, error = err })
		footer.notify("warn", err)
		on_done(nil, err)
		return
	end

	action.run(ctx, on_done)
end

---@param ctx JiraActionContext
---@param on_done fun(result: JiraActionResult|nil, err: string|nil)
function M.open(ctx, on_done)
	local actions = registry.available(ctx)
	if #actions == 0 then
		on_done({ changed_issue_key = nil, message = "No actions available" }, nil)
		return
	end

	vim.ui.select(actions, {
		prompt = "Choose Jira action",
		kind = "atlas_jira_actions",
		format_item = function(item)
			return tostring((item and item.label) or "")
		end,
	}, function(action)
		if action == nil then
			on_done({ changed_issue_key = nil, message = "Action cancelled" }, nil)
			return
		end

		action.run(ctx, on_done)
	end)
end

return M
