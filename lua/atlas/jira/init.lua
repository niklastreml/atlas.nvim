local M = {}

local config = require("atlas.config")
local controller = require("atlas.jira.ui.controller")
local actions = require("atlas.jira.ui.actions")
local help = require("atlas.ui.popups.help")
local navigation = require("atlas.ui.navigation")
local layout = require("atlas.ui.layout")
local footer = require("atlas.ui.components.footer")

---@return JiraIssue|nil
local function selected_issue()
	local node = navigation.current_item()
	if type(node) ~= "table" then
		return nil
	end

	if node.kind == "issue" and type(node._issue) == "table" then
		return node._issue
	end

	return nil
end

local function register_dynamic_keys(buf, views)
	local items = {
		{
			key = "r",
			desc = "Reload selected issue",
			callback = function()
				controller.refresh_current_issue()
			end,
		},
		{
			key = "R",
			desc = "Refresh current Jira view",
			callback = function()
				controller.refresh_current_view(function()
					navigation.focus_first_item()
				end)
			end,
		},
		{
			key = "K",
			desc = "Show issue details popup",
			callback = function()
				controller.show_issue_details(buf)
			end,
		},
		{
			key = "A",
			desc = "Open Jira actions",
			callback = function()
				controller.open_actions()
			end,
		},
		{
			key = "c",
			desc = "Create Jira issue",
			callback = function()
				actions.create_issue()
			end,
		},
		{
			key = "gx",
			desc = "Open issue in browser",
			callback = function()
				actions.browse_issue(selected_issue())
			end,
		},
		{
			key = "y",
			desc = "Copy issue key",
			callback = function()
				actions.copy_issue_key(selected_issue())
			end,
		},
		{
			key = "Y",
			desc = "Copy issue URL",
			callback = function()
				actions.copy_issue_url(selected_issue())
			end,
		},
		{
			key = "/",
			desc = "Search issues",
			callback = function()
				controller.open_issue_search_popup()
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
		help.unregister_key("Jira", item.key, { buf = buf })
	end
	for _, item in ipairs(view_items) do
		help.unregister_key("Jira", item.key, { buf = buf })
	end

	help.register_keys("Jira", items, {
		index = 220,
		buf = buf,
	})

	help.register_keys("Jira", view_items, {
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

	local views = (config.options.jira and config.options.jira.views) or {}
	register_dynamic_keys(target_buf, views)
end

return M
