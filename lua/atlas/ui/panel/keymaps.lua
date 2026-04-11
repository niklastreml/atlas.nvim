local M = {}

local help = require("atlas.ui.popups.help")
local resolver = require("atlas.core.keymaps")
local utils = require("atlas.utils")
local state = require("atlas.ui.panel.state")

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

local function current_panel_controller()
	local provider = state.active_provider
	if provider == "jira" then
		return require("atlas.jira.panel")
	end

	return require("atlas.bitbucket.panel.init")
end

local function refresh_current_panel()
	local provider = state.active_provider
	if provider == "jira" then
		local panel = require("atlas.jira.panel")
		if type(panel.refresh_tab) == "function" then
			panel.refresh_tab()
			return
		end
		panel.refresh()
		return
	end

	local panel = require("atlas.bitbucket.panel.init")
	if type(panel.refresh_tab) == "function" then
		panel.refresh_tab({ force_load = true })
		return
	end
	panel.refresh()
end

---@param buf integer
function M.register(buf)
	local items = {}
	local function add(action_id, map_item)
		utils.insert_if(items, item(action_id, map_item))
	end

	add("ui.help", {
		desc = "Toggle this help popup",
		opts = { silent = true, nowait = true },
		callback = function()
			help.toggle({ buffer = buf })
		end,
	})

	add("ui.close", {
		desc = "Close detail pane",
		opts = { silent = true, nowait = true },
		callback = function()
			if help.is_open() then
				return
			end
			require("atlas.ui.panel").close()
		end,
	})

	add("ui.toggle_panel", {
		desc = "Toggle detail pane",
		opts = { silent = true, nowait = true },
		callback = function()
			require("atlas.ui.panel").toggle()
		end,
	})

	add("ui.previous_panel_tab", {
		desc = "Previous panel tab",
		opts = { silent = true, nowait = true },
		callback = function()
			current_panel_controller().prev_tab()
		end,
	})

	add("ui.next_panel_tab", {
		desc = "Next panel tab",
		opts = { silent = true, nowait = true },
		callback = function()
			current_panel_controller().next_tab()
		end,
	})

	add("ui.refresh", {
		desc = "Refresh current panel",
		opts = { silent = true, nowait = true },
		callback = function()
			refresh_current_panel()
		end,
	})

	M.remove(buf)
	help.register("General", items, { index = 210, buffer = buf })
end

---@param buf integer
function M.remove(buf)
	local items = {}
	utils.insert_if(items, remove_item("ui.help"))
	utils.insert_if(items, remove_item("ui.close"))
	utils.insert_if(items, remove_item("ui.toggle_panel"))
	utils.insert_if(items, remove_item("ui.previous_panel_tab"))
	utils.insert_if(items, remove_item("ui.next_panel_tab"))
	utils.insert_if(items, remove_item("ui.refresh"))

	help.remove("General", items, { buffer = buf })
end

return M
