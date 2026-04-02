local M = {}

local registry = require("atlas.jira.actions.registry")

---@param action_id string
---@param ctx JiraActionContext
---@param on_done fun(result: JiraActionResult|nil, err: string|nil)
function M.run(action_id, ctx, on_done)
	local action = registry.find(action_id)
	if action == nil then
		on_done(nil, string.format("Unknown action: %s", tostring(action_id)))
		return
	end

	if not action.is_available(ctx) then
		on_done(nil, string.format("Action not available: %s", tostring(action.label or action_id)))
		return
	end

	action.run(ctx, on_done)
end

---@param ctx JiraActionContext
---@param on_done fun(result: JiraActionResult|nil, err: string|nil)
function M.open(ctx, on_done)
	local actions = registry.available(ctx)
	if #actions == 0 then
		on_done({ changed_issue = false, message = "No actions available" }, nil)
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
			on_done({ changed_issue = false, message = "Action cancelled" }, nil)
			return
		end

		action.run(ctx, on_done)
	end)
end

return M
