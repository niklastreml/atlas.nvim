local M = {}

local config = require("atlas.config")
local controller = require("atlas.jira.ui.controller")
local keymaps = require("atlas.jira.keymaps")
local help = require("atlas.ui.popups.help")
local layout = require("atlas.ui.layout")
local footer = require("atlas.ui.components.footer")
local state = require("atlas.jira.state")

local function register_keymaps(buf, views)
	keymaps.register(buf)

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

	help.register("Jira", view_items, {
		index = 220,
		buffer = buf,
	})
end

---@param opts { initial_view?: JiraViewConfig }|nil
function M.setup(opts)
	opts = opts or {}

	if opts.initial_view ~= nil then
		state.active_view = opts.initial_view
	else
		local views = (config.options.jira and config.options.jira.views) or {}
		if state.active_view == nil then
			state.active_view = views[1]
		end
	end

	footer.clear_items()

	local target_buf = layout.buf_id("main")
	if target_buf == nil or not vim.api.nvim_buf_is_valid(target_buf) then
		return
	end

	local views = (config.options.jira and config.options.jira.views) or {}
	register_keymaps(target_buf, views)

	require("atlas.ui.state").current_view = "jira"
	require("atlas.jira.ui").render()
	require("atlas.jira.ui").init()
end

---@param item table|nil
---@return AtlasJiraPanelSelection|nil
function M.panel_selection_from_item(item)
	if type(item) ~= "table" or type(item._issue) ~= "table" then
		return nil
	end

	return {
		provider = "jira",
		item = item._issue,
	}
end

return M
