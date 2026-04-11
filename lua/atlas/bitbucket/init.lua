local M = {}

local config = require("atlas.config")
local controller = require("atlas.bitbucket.ui.controller")
local bitbucket_keymaps = require("atlas.bitbucket.keymaps")
local help = require("atlas.ui.popups.help")
local layout = require("atlas.ui.layout")
local footer = require("atlas.ui.components.footer")
local state = require("atlas.bitbucket.state")

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
					controller.switch_view(v)
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
	if state.active_view == nil then
		local views = (config.options.bitbucket and config.options.bitbucket.views) or {}
		state.active_view = views[1]
	end

	footer.clear_items()

	local target_buf = layout.buf_id("main")
	if target_buf == nil or not vim.api.nvim_buf_is_valid(target_buf) then
		return
	end

	local views = (config.options.bitbucket and config.options.bitbucket.views) or {}
	register_dynamic_keys(target_buf, views)
	require("atlas.ui.state").current_view = "bitbucket"
	require("atlas.bitbucket.ui").render()
	require("atlas.bitbucket.ui").init()
end

---@param item table|nil
---@return AtlasBitbucketPanelSelection|nil
function M.panel_selection_from_item(item)
	if type(item) ~= "table" then
		return nil
	end

	if (item.kind == "pr" or item.kind == "pr_meta") and type(item.pr) == "table" then
		return {
			provider = "bitbucket",
			panel_type = "pr",
			item = item.pr,
		}
	end

	if type(item._repo) == "table" then
		return {
			provider = "bitbucket",
			panel_type = "repo",
			item = item._repo,
		}
	end

	return nil
end

return M
