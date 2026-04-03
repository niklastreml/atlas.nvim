local M = {}

local registry = require("atlas.bitbucket.actions.registry")

---@param ctx BitbucketActionContext
---@param on_done fun(result: BitbucketActionResult|nil, err: string|nil)
function M.open(ctx, on_done)
	local actions = registry.available(ctx)
	if #actions == 0 then
		on_done({ changed_pr = false, message = "No actions available" }, nil)
		return
	end

	local pr_label = ""
	if ctx.pr ~= nil then
		pr_label = string.format(" PR #%s", tostring(ctx.pr.id or ""))
	end

	vim.ui.select(actions, {
		prompt = string.format("Choose Bitbucket action%s", pr_label),
		kind = "atlas_bitbucket_actions",
		format_item = function(item)
			return tostring((item and item.label) or "")
		end,
	}, function(action)
		if action == nil then
			on_done({ changed_pr = false, message = "Action cancelled" }, nil)
			return
		end

		action.run(ctx, on_done)
	end)
end

return M
