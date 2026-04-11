local M = {}

local config = require("atlas.config")
local controller = require("atlas.bitbucket.ui.controller")
local bitbucket_keymaps = require("atlas.bitbucket.keymaps")
local help = require("atlas.ui.popups.help")
local navigation = require("atlas.ui.navigation")
local layout = require("atlas.ui.layout")
local footer = require("atlas.ui.components.footer")

---@param buf integer
---@param views BitbucketViewConfig[]
local function register_dynamic_keys(buf, views)
	bitbucket_keymaps.register(buf)
	local view_items = {}

	for _, view in ipairs(views or {}) do
		if view.key ~= nil and view.key ~= "" then
			local v = view
			table.insert(view_items, {
				key = v.key,
				desc = string.format("Switch to %s", v.name),
				hidden = true,
				callback = function()
					controller.switch_view(v, function()
						navigation.focus_first_item()
					end)
				end,
			})
		end
	end

	help.register("Bitbucket", view_items, {
		index = 220,
		buffer = buf,
	})
end

function M.setup()
	footer.clear_items()

	local target_buf = layout.buf_id("main")
	if target_buf == nil or not vim.api.nvim_buf_is_valid(target_buf) then
		return
	end

	local views = (config.options.bitbucket and config.options.bitbucket.views) or {}
	register_dynamic_keys(target_buf, views)
end

return M
