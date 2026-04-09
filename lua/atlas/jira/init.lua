local M = {}

local config = require("atlas.config")
local controller = require("atlas.jira.ui.controller")
local actions = require("atlas.jira.ui.actions")
local jira_actions = require("atlas.jira.actions")
local help = require("atlas.ui.popups.help")
local navigation = require("atlas.ui.navigation")
local layout = require("atlas.ui.layout")
local footer = require("atlas.ui.components.footer")
local state = require("atlas.jira.state")

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

---@param action_id string
---@param message_prefix string
local function run_selected_issue_action(action_id, message_prefix)
	local issue = selected_issue()
	if issue == nil then
		footer.notify("warn", "No issue selected")
		return
	end

	jira_actions.run(action_id, { issue = issue, source = "main" }, function(result, err)
		if err ~= nil then
			footer.notify("error", tostring(err))
			return
		end

		if result ~= nil and result.message ~= nil and result.message ~= "" then
			footer.notify("info", string.format("%s: %s", message_prefix, result.message), 1200)
		end

		if result ~= nil and result.changed_issue_key ~= nil and result.changed_issue_key ~= "" then
			controller.refresh_issue(result.changed_issue_key)
		end
	end)
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
			key = "ge",
			desc = "Edit issue",
			callback = function()
				run_selected_issue_action("edit_issue", "Edit issue")
			end,
		},
		{
			key = "gs",
			desc = "Transition issue",
			callback = function()
				run_selected_issue_action("transition", "Transition")
			end,
		},
		{
			key = "ga",
			desc = "Change assignee",
			callback = function()
				run_selected_issue_action("assign", "Change assignee")
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

---@param opts { initial_view?: JiraViewConfig }|nil
function M.setup(opts)
	opts = opts or {}
	if opts.initial_view ~= nil then
		state.active_view = opts.initial_view
	end

	footer.clear_items()

	local target_buf = layout.buf_id("main")
	if target_buf == nil or not vim.api.nvim_buf_is_valid(target_buf) then
		return
	end

	local views = (config.options.jira and config.options.jira.views) or {}
	register_dynamic_keys(target_buf, views)
end

return M
