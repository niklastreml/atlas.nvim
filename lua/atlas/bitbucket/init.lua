local M = {}

local config = require("atlas.config")
local actions = require("atlas.bitbucket.actions")
local help = require("atlas.ui.popups.help")
local navigation = require("atlas.ui.navigation")
local layout = require("atlas.ui.layout")
local footer = require("atlas.ui.components.footer")

---@param buf integer
---@param views BitbucketViewConfig[]
local function register_dynamic_keys(buf, views)
	local items = {
		{
			key = "r",
			desc = "Refresh current Bitbucket view",
			callback = function()
				actions.refresh_current_view(function()
					navigation.focus_first_item()
				end)
			end,
		},
	}

	for _, view in ipairs(views or {}) do
		if view.key ~= nil and view.key ~= "" then
			local v = view
			table.insert(items, {
				key = v.key,
				desc = string.format("Switch to %s", v.name),
				callback = function()
					actions.switch_view(v, function()
						navigation.focus_first_item()
					end)
				end,
			})
		end
	end

	for _, item in ipairs(items) do
		help.unregister_key("Bitbucket", item.key, { buf = buf })
	end

	help.register_keys("Bitbucket", items, {
		index = 220,
		add_to_registry = false,
		buf = buf,
	})
end

function M.setup()
	footer.clear_items()

	local target_buf = layout.main_buf_id()
	if target_buf == nil or not vim.api.nvim_buf_is_valid(target_buf) then
		return
	end

	local views = (config.options.bitbucket and config.options.bitbucket.views) or {}
	register_dynamic_keys(target_buf, views)
end

return M
