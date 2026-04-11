local M = {}

local help = require("atlas.ui.popups.help")
local resolver = require("atlas.core.keymaps")
local utils = require("atlas.utils")

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
	local items = {
		{
			key = "q",
			desc = "Close Atlas window",
			opts = { nowait = true, silent = true },
			callback = function()
				if help.is_open() then
					return
				end
				require("atlas.ui.layout").close()
			end,
		},
		{
			key = "?",
			desc = "Toggle this help popup",
			opts = { nowait = true, silent = true },
			callback = function()
				help.toggle({ buffer = buf })
			end,
		},
		{
			key = "j",
			desc = "Next item",
			hidden = true,
			callback = function()
				require("atlas.ui.navigation").move_cursor("down")
			end,
		},
		{
			key = "k",
			desc = "Previous item",
			hidden = true,
			callback = function()
				require("atlas.ui.navigation").move_cursor("up")
			end,
		},
		{
			key = "gg",
			desc = "Go to first PR",
			hidden = true,
			callback = function()
				require("atlas.ui.navigation").focus_first_item()
			end,
		},
		{
			key = "G",
			desc = "Go to last PR",
			hidden = true,
			callback = function()
				require("atlas.ui.navigation").focus_last_item()
			end,
		},
	}

	local function add(action_id, map_item)
		utils.insert_if(items, item(action_id, map_item))
	end

	add("ui.toggle_panel", {
		desc = "Toggle detail pane",
		callback = function()
			local panel = require("atlas.ui.panel")
			local navigation = require("atlas.ui.navigation")
			local panel_state = require("atlas.ui.panel.state")
			local ui_state = require("atlas.ui.state")
			local current = navigation.current_item()
			if panel.is_open() then
				if panel_state.active_provider == ui_state.current_view then
					panel.close()
					return
				end
			end

			local selection = nil
			if ui_state.current_view == "jira" then
				selection = require("atlas.jira").panel_selection_from_item(current)
			elseif ui_state.current_view == "bitbucket" then
				selection = require("atlas.bitbucket").panel_selection_from_item(current)
			end

			if selection ~= nil then
				panel.show(selection)
			end
		end,
	})

	add("ui.previous_panel_tab", {
		desc = "Previous panel tab",
		opts = { silent = true, nowait = true },
		callback = function()
			local panel = require("atlas.ui.panel")
			if not panel.is_open() then
				return
			end

			local ui_state = require("atlas.ui.state")
			if ui_state.current_view == "jira" then
				require("atlas.jira.panel.init").prev_tab()
			elseif ui_state.current_view == "bitbucket" then
				require("atlas.bitbucket.panel.init").prev_tab()
			end
		end,
	})

	add("ui.next_panel_tab", {
		desc = "Next panel tab",
		opts = { silent = true, nowait = true },
		callback = function()
			local panel = require("atlas.ui.panel")
			if not panel.is_open() then
				return
			end

			local ui_state = require("atlas.ui.state")
			if ui_state.current_view == "jira" then
				require("atlas.jira.panel.init").next_tab()
			elseif ui_state.current_view == "bitbucket" then
				require("atlas.bitbucket.panel.init").next_tab()
			end
		end,
	})

	M.remove(buf)
	help.register("General", items, { index = 210, buffer = buf })
end

---@param buf integer
function M.remove(buf)
	local items = {
		{ key = "q" },
		{ key = "?" },
		{ key = "j" },
		{ key = "k" },
		{ key = "gg" },
		{ key = "G" },
	}
	utils.insert_if(items, remove_item("ui.toggle_panel"))
	utils.insert_if(items, remove_item("ui.previous_panel_tab"))
	utils.insert_if(items, remove_item("ui.next_panel_tab"))

	help.remove("General", items, { buffer = buf })
end

return M
