local M = {}

local footer = require("atlas.ui.components.footer")
local resolver = require("atlas.core.keymaps")
local utils = require("atlas.shared.utils")

---@return PullRequest|nil
local function selected_pr()
	local navigation = require("atlas.ui.navigation")
	local node = navigation.current_item()
	if type(node) ~= "table" then
		return nil
	end
	if node.kind == "pr" and type(node.pr) == "table" then
		return node.pr
	end
	if node.kind == "pr_meta" and type(node.pr) == "table" then
		return node.pr
	end
	return nil
end

---@param action_id AtlasKeymapActionId|string
---@param map_item table
---@return table|nil
local function item(action_id, map_item)
	local keys = resolver.resolve(action_id)
	if keys == nil then
		return nil
	end

	local out = vim.tbl_deep_extend("force", {}, map_item)
	out.key = #keys == 1 and keys[1] or keys
	return out
end

---@param action_id AtlasKeymapActionId|string
---@param mode string|string[]|nil
---@return table|nil
local function remove_item(action_id, mode)
	local keys = resolver.resolve(action_id)
	if keys == nil then
		return nil
	end

	local out = { key = (#keys == 1 and keys[1] or keys) }
	if mode ~= nil then
		out.mode = mode
	end
	return out
end

---@param buf integer
---@param views PullsView[]
function M.register(buf, views)
	local help = require("atlas.ui.popups.help")
	local controller = require("atlas.pulls.ui.main.controller")
	local state = require("atlas.pulls.state")
	local provider_name = state.provider and state.provider.name or "Pulls"

	local items = {}

	for _, view in ipairs(views or {}) do
		if view.key ~= nil and view.key ~= "" then
			local v = view
			table.insert(items, {
				key = v.key,
				desc = string.format("Switch to %s", v.name),
				hidden = true,
				callback = function()
					controller.switch_view(v)
				end,
			})
		end
	end

	if state.provider and state.provider.open_actions then
		utils.insert_if(items, item("pulls.open_actions", {
			desc = "Open PR actions",
			index = 1,
			callback = function()
				local pr = selected_pr()
				if pr == nil then
					footer.notify("warn", "No PR selected")
					return
				end

				state.provider.open_actions(pr, { source = "main" }, function(result)
					if result ~= nil and result.changed_pr then
						controller.refresh_pr(pr)
					end
				end)
			end,
		}))
	end

	utils.insert_if(items, item("pulls.refresh", {
		desc = "Refetch selected PR",
		callback = function()
			local pr = selected_pr()
			if pr == nil then
				footer.notify("warn", "No PR selected")
				return
			end
			controller.refresh_pr(pr)
		end,
	}))

	utils.insert_if(items, item("pulls.refresh_view", {
		desc = "Refresh current view",
		callback = function()
			controller.refresh_current_view()
		end,
	}))

	help.register(provider_name, items, { index = 220, buffer = buf })
end

return M
