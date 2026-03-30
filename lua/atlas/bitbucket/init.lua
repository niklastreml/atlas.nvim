local M = {}

local config = require("atlas.config")
local controller = require("atlas.bitbucket.ui.main.controller")
local main_actions = require("atlas.bitbucket.ui.main.actions")
local help = require("atlas.ui.popups.help")
local navigation = require("atlas.ui.navigation")
local layout = require("atlas.ui.layout")
local footer = require("atlas.ui.components.footer")

---@return BitbucketPR|nil
local function selected_pr()
	local node = navigation.current_item()
	if type(node) ~= "table" then
		return nil
	end
	if node.kind == "pr" and type(node.pr) == "table" then
		return node.pr
	end
	if node.kind == "pr" then
		return node
	end
	return nil
end

---@param buf integer
---@param views BitbucketViewConfig[]
local function register_dynamic_keys(buf, views)
	local items = {
		{
			key = "a",
			desc = "Open PR actions",
			callback = function()
				main_actions.open_pr_actions_popup(selected_pr())
			end,
		},
		{
			key = "gx",
			desc = "Open PR in browser",
			callback = function()
				main_actions.browse_current_pr(selected_pr())
			end,
		},
		{
			key = "y",
			desc = "Copy PR id",
			callback = function()
				main_actions.copy_current_pr_id(selected_pr())
			end,
		},
		{
			key = "Y",
			desc = "Copy PR URL",
			callback = function()
				main_actions.copy_current_pr_url(selected_pr())
			end,
		},
		{
			key = "gg",
			desc = "Go to first PR",
			callback = function()
				navigation.focus_first_item()
			end,
		},
		{
			key = "G",
			desc = "Go to last PR",
			callback = function()
				navigation.focus_last_item()
			end,
		},
		{
			key = "R",
			desc = "Refresh current Bitbucket view",
			callback = function()
				controller.refresh_current_view(function()
					navigation.focus_first_item()
				end)
			end,
		},
		{
			key = "/",
			desc = "Search repositories",
			callback = function()
				main_actions.open_pr_search_popup()
			end,
		},
	}
	local view_items = {}

	for _, view in ipairs(views or {}) do
		if view.key ~= nil and view.key ~= "" then
			local v = view
			table.insert(view_items, {
				key = v.key,
				desc = string.format("Switch to %s", v.name),
				callback = function()
					controller.switch_view(v, function()
						navigation.focus_first_item()
					end)
				end,
			})
		end
	end

	for _, item in ipairs(items) do
		help.unregister_key("Bitbucket", item.key, { buf = buf })
	end
	for _, item in ipairs(view_items) do
		help.unregister_key("Bitbucket", item.key, { buf = buf })
	end

	help.register_keys("Bitbucket", items, {
		index = 220,
		buf = buf,
	})

	help.register_keys("Bitbucket", view_items, {
		index = 220,
		buf = buf,
		add_to_registry = false,
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
