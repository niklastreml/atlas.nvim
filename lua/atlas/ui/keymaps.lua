local M = {}

local help = require("atlas.ui.popups.help")
local resolver = require("atlas.core.keymaps")
local utils = require("atlas.shared.utils")

---@param action_id AtlasKeymapActionId|string
---@param map_item table
---@return table|nil
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
---@return table|nil
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
			desc = "Go to first item",
			hidden = true,
			callback = function()
				require("atlas.ui.navigation").focus_first_item()
			end,
		},
		{
			key = "G",
			desc = "Go to last item",
			hidden = true,
			callback = function()
				require("atlas.ui.navigation").focus_last_item()
			end,
		},
	}

	utils.insert_if(items, item("ui.help", {
		desc = "Toggle this help popup",
		opts = { nowait = true, silent = true },
		callback = function()
			help.toggle({ buffer = buf })
		end,
	}))

	utils.insert_if(items, item("ui.close", {
		desc = "Close Atlas window",
		opts = { nowait = true, silent = true },
		callback = function()
			if help.is_open() then
				return
			end
			require("atlas.ui.layout").close()
		end,
	}))

	utils.insert_if(items, item("ui.toggle_panel", {
		desc = "Toggle detail panel",
		callback = function()
			require("atlas.ui.layout").toggle_detail()
		end,
	}))

	M.remove(buf)
	help.register("General", items, { index = 210, buffer = buf })
end

---@param buf integer
function M.remove(buf)
	local items = {
		{ key = "j" },
		{ key = "k" },
		{ key = "gg" },
		{ key = "G" },
	}
	utils.insert_if(items, remove_item("ui.help"))
	utils.insert_if(items, remove_item("ui.close"))
	utils.insert_if(items, remove_item("ui.toggle_panel"))

	help.remove("General", items, { buffer = buf })
end

return M
