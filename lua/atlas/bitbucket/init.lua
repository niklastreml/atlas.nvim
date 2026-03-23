local M = {}

local config = require("atlas.config")
local ui_state = require("atlas.ui.state")
local renderer = require("atlas.ui.renderer")
local state = require("atlas.bitbucket.state")
local help = require("atlas.ui.popups.help")

---@param buf integer
---@param views BitbucketViewConfig[]
local function register_dynamic_keys(buf, views)
	local items = {
		{
			key = "r",
			desc = "Refresh current Bitbucket view",
			callback = function()
				renderer.render("bitbucket", { force_refresh = true })
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
					state.active_view = v
					renderer.render("bitbucket")
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

function M.setup() end
local footer = require("atlas.ui.components.footer")

footer.clear_items("bitbucket")
---TODO: add better options. This is just for testing.
footer.register_item("bitbucket", { text = "PRs", hl_group = "AtlasFooterText" })
footer.register_item("bitbucket", { text = "|", hl_group = "AtlasFooterText" })
footer.register_item("bitbucket", { text = "r refresh", hl_group = "AtlasFooterText" })

local target_buf = ui_state.buf_id
if target_buf == nil or not vim.api.nvim_buf_is_valid(target_buf) then
	return
end

local views = (config.options.bitbucket and config.options.bitbucket.views) or {}
register_dynamic_keys(target_buf, views)

return M
