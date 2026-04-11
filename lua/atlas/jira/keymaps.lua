local M = {}

local resolver = require("atlas.core.keymaps")
local help = require("atlas.ui.popups.help")
local utils = require("atlas.utils")
local controller = require("atlas.jira.ui.controller")
local jira_actions = require("atlas.jira.actions")
local navigation = require("atlas.ui.navigation")
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

---@param action_id JiraActionId|string
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

---@param action_id string
---@param item_opts table
---@return AtlasHelpKeyItem|nil
local function item(action_id, item_opts)
	local keys = resolver.resolve(action_id)
	if keys == nil then
		return nil
	end

	local out = vim.tbl_deep_extend("force", {}, item_opts)
	out.key = #keys == 1 and keys[1] or keys
	return out
end

---@param action_id string
---@param mode string|string[]|nil
---@return { key: string|string[], mode?: string|string[] }|nil
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
function M.register(buf)
	local items = {}
	local function add(action_id, item_opts)
		utils.insert_if(items, item(action_id, item_opts))
	end

	add("jira.open_actions", {
		desc = "Open Jira actions",
		index = 1,
		callback = function()
			controller.open_actions()
		end,
	})

	add("jira.search", {
		desc = "Search issues",
		index = 2,
		callback = function()
			jira_actions.run("search_query_issue", { issue = nil, source = "main" }, function(result, err)
				if err ~= nil then
					footer.notify("error", tostring(err))
					return
				end

				if result ~= nil and result.message ~= nil and result.message ~= "" then
					footer.notify("info", result.message, 1200)
				end
			end)
		end,
	})

	add("jira.edit_issue", {
		desc = "Edit issue",
		index = 3,
		callback = function()
			run_selected_issue_action("edit_issue", "Edit issue")
		end,
	})

	add("jira.transition_issue", {
		desc = "Transition issue",
		index = 4,
		callback = function()
			run_selected_issue_action("transition", "Transition")
		end,
	})

	add("jira.change_assignee", {
		desc = "Change assignee",
		index = 5,
		callback = function()
			run_selected_issue_action("assign", "Change assignee")
		end,
	})

	add("jira.open_in_browser", {
		desc = "Open issue in browser",
		index = 6,
		callback = function()
			run_selected_issue_action("browse_issue", "Open issue")
		end,
	})

	add("jira.create_issue", {
		desc = "Create Jira issue",
		index = 7,
		callback = function()
			jira_actions.run("create_issue", { issue = nil, source = "main", description = nil }, function(result, err)
				if err ~= nil then
					footer.notify("error", tostring(err))
					return
				end

				if result ~= nil and result.changed_issue_key ~= nil and result.changed_issue_key ~= "" then
					controller.refresh_issue(result.changed_issue_key)
				end
			end)
		end,
	})

	add("jira.refresh_issue", {
		desc = "Reload selected issue",
		index = 8,
		callback = function()
			controller.refresh_current_issue()
		end,
	})

	add("jira.refresh_view", {
		desc = "Refresh current view",
		index = 9,
		callback = function()
			controller.refresh_current_view()
		end,
	})

	add("jira.show_details", {
		desc = "Show issue details",
		callback = function()
			controller.show_issue_details(buf)
		end,
	})

	add("jira.copy_key", {
		desc = "Copy issue key",
		callback = function()
			run_selected_issue_action("copy_issue_key", "Copy issue key")
		end,
	})

	add("jira.copy_url", {
		desc = "Copy issue URL",
		callback = function()
			run_selected_issue_action("copy_issue_url", "Copy issue URL")
		end,
	})

	M.remove(buf)
	help.register("Jira", items, {
		index = 220,
		buffer = buf,
	})
end

---@param buf integer
function M.remove(buf)
	local items = {}
	utils.insert_if(items, remove_item("jira.open_actions"))
	utils.insert_if(items, remove_item("jira.search"))
	utils.insert_if(items, remove_item("jira.edit_issue"))
	utils.insert_if(items, remove_item("jira.transition_issue"))
	utils.insert_if(items, remove_item("jira.change_assignee"))
	utils.insert_if(items, remove_item("jira.open_in_browser"))
	utils.insert_if(items, remove_item("jira.create_issue"))
	utils.insert_if(items, remove_item("jira.refresh_issue"))
	utils.insert_if(items, remove_item("jira.refresh_view"))
	utils.insert_if(items, remove_item("jira.show_details"))
	utils.insert_if(items, remove_item("jira.copy_key"))
	utils.insert_if(items, remove_item("jira.copy_url"))

	help.remove("Jira", items, { buffer = buf })
end

return M
