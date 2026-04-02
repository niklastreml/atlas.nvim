local M = {}

local transitions_api = require("atlas.jira.api.transitions")
local footer = require("atlas.ui.components.footer")

---@class JiraActionContext
---@field issue JiraIssue|nil
---@field source "panel"|"main"|nil

---@class JiraActionResult
---@field changed_issue boolean
---@field message string|nil

---@class JiraActionDef
---@field id string
---@field label string
---@field is_available fun(ctx: JiraActionContext): boolean
---@field run fun(ctx: JiraActionContext, done: fun(result: JiraActionResult|nil, err: string|nil))

---@param ctx JiraActionContext
---@return boolean
local function has_issue_key(ctx)
	return type(ctx) == "table"
		and type(ctx.issue) == "table"
		and type(ctx.issue.key) == "string"
		and ctx.issue.key ~= ""
end

---@type JiraActionDef[]
local ACTIONS = {
	{
		id = "transition",
		label = "Transition",
		is_available = has_issue_key,
		run = function(ctx, done)
			if not has_issue_key(ctx) then
				done(nil, "No issue selected")
				return
			end

			local issue = ctx.issue
			local issue_key = type(issue) == "table" and issue.key or nil
			local current_status = type(issue) == "table" and tostring(issue.status or "") or ""
			if type(issue_key) ~= "string" or issue_key == "" then
				done(nil, "No issue selected")
				return
			end

			footer.notify("loading", string.format("Loading transitions for %s...", issue_key))
			transitions_api.get_transitions(issue_key, function(page, err)
				if err ~= nil or page == nil then
					footer.notify("error", err or "Failed to load transitions")
					done(nil, err or "Failed to load transitions")
					return
				end

				footer.notify("success", string.format("Loaded transitions for %s...", issue_key))

				local transitions = {}
				for _, transition in ipairs(page.transitions or {}) do
					local to_status = tostring((transition and transition.to_status_name) or "")
					if current_status == "" or to_status == "" or to_status ~= current_status then
						table.insert(transitions, transition)
					end
				end
				if #transitions == 0 then
					footer.notify("info", "No transitions available", 1200)
					done({ changed_issue = false, message = "No transitions available" }, nil)
					return
				end

				vim.ui.select(transitions, {
					prompt = string.format("Transition %s", issue_key),
					kind = "atlas_jira_transitions",
					format_item = function(item)
						return tostring((item and item.name) or "")
					end,
				}, function(selected)
					if selected == nil then
						done({ changed_issue = false, message = "Transition cancelled" }, nil)
						return
					end

					footer.notify("loading", string.format("Transitioning %s...", issue_key))
					transitions_api.transition_issue(issue_key, selected.id, function(ok, transition_err)
						if not ok then
							footer.notify("error", transition_err or "Transition failed")
							done(nil, transition_err or "Transition failed")
							return
						end

						footer.notify(
							"success",
							string.format("Transitioned %s to %s", issue_key, selected.name or "status"),
							1200
						)

						done({
							changed_issue = true,
							message = string.format("Transitioned to %s", selected.name or "status"),
						}, nil)
					end)
				end)
			end)
		end,
	},
	{
		id = "assign",
		label = "Change assignee",
		is_available = has_issue_key,
		run = function(_, done)
			done(nil, "Change assignee not implemented yet")
		end,
	},
}

---@param ctx JiraActionContext
---@return JiraActionDef[]
function M.available(ctx)
	local out = {}
	for _, action in ipairs(ACTIONS) do
		if action.is_available(ctx) then
			table.insert(out, action)
		end
	end
	return out
end

---@param id string
---@return JiraActionDef|nil
function M.find(id)
	for _, action in ipairs(ACTIONS) do
		if action.id == id then
			return action
		end
	end
	return nil
end

return M
