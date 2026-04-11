local M = {}

local help = require("atlas.ui.popups.help")
local resolver = require("atlas.core.keymaps")
local utils = require("atlas.utils")
local panel_state = require("atlas.jira.panel.state")
local footer = require("atlas.ui.components.footer")
local jira_actions = require("atlas.jira.actions")
local jira_controller = require("atlas.jira.ui.controller")

local TAB_MODULES = {
	overview = "atlas.jira.panel.tabs.overview",
	comments = "atlas.jira.panel.tabs.comments",
	history = "atlas.jira.panel.tabs.history",
}

---@param tab_key string
---@return table|nil
local function get_tab_module(tab_key)
	local mod = TAB_MODULES[tab_key]
	if mod == nil then
		return nil
	end

	return require(mod)
end

---@param action_id AtlasKeymapActionId|string
---@param map_item table
---@return AtlasHelpKeyItem|nil
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
	local navigation_items = {
		{
			key = "j",
			desc = "Next item in tab",
			opts = { silent = true, nowait = true },
			hidden = true,
			callback = function()
				local tab = get_tab_module(panel_state.current_tab)
				if tab ~= nil and type(tab.move_cursor) == "function" then
					tab.move_cursor(1)
				end
			end,
		},
		{
			key = "k",
			desc = "Previous item in tab",
			opts = { silent = true, nowait = true },
			hidden = true,
			callback = function()
				local tab = get_tab_module(panel_state.current_tab)
				if tab ~= nil and type(tab.move_cursor) == "function" then
					tab.move_cursor(-1)
				end
			end,
		},
		{
			key = "gg",
			desc = "First item in tab",
			opts = { silent = true, nowait = true },
			hidden = true,
			callback = function()
				local tab = get_tab_module(panel_state.current_tab)
				if tab ~= nil and type(tab.move_cursor) == "function" then
					tab.move_cursor(0)
				end
			end,
		},
		{
			key = "G",
			desc = "Last item in tab",
			opts = { silent = true, nowait = true },
			hidden = true,
			callback = function()
				local tab = get_tab_module(panel_state.current_tab)
				if tab ~= nil and type(tab.move_cursor) == "function" then
					tab.move_cursor(math.huge)
				end
			end,
		},
	}

	local jira_items = {}
	local function add(action_id, map_item)
		utils.insert_if(jira_items, item(action_id, map_item))
	end

	add("jira.refresh_tab", {
		desc = "Refresh current tab",
		opts = { silent = true, nowait = true },
		callback = function()
			local tab = get_tab_module(panel_state.current_tab)
			if tab ~= nil and type(tab.refresh) == "function" then
				tab.refresh()
			end
		end,
	})

	add("jira.open_actions", {
		desc = "Open Jira actions",
		opts = { silent = true, nowait = true },
		callback = function()
			local issue = panel_state.current_issue
			if type(issue) ~= "table" then
				footer.notify("warn", "No issue selected")
				return
			end

			jira_actions.open({ issue = issue, source = "panel" }, function(result, err)
				if err ~= nil then
					footer.notify("error", tostring(err))
					return
				end

				if result ~= nil and result.message ~= nil and result.message ~= "" then
					footer.notify("info", result.message, 1200)
				end

				if result ~= nil and result.changed_issue_key ~= nil and result.changed_issue_key ~= "" then
					jira_controller.refresh_issue(result.changed_issue_key, function()
						require("atlas.jira.panel").refresh()
					end)
				end
			end)
		end,
	})

	M.remove(buf)
	help.register("Navigation", navigation_items, { index = 999, buffer = buf })
	help.register("Jira", jira_items, { index = 220, buffer = buf })
end

---@param buf integer
function M.remove(buf)
	help.remove("Navigation", {
		{ key = "j" },
		{ key = "k" },
		{ key = "gg" },
		{ key = "G" },
	}, { buffer = buf })

	local jira_items = {}
	utils.insert_if(jira_items, remove_item("jira.refresh_tab"))
	utils.insert_if(jira_items, remove_item("jira.open_actions"))
	help.remove("Jira", jira_items, { buffer = buf })
end

return M
