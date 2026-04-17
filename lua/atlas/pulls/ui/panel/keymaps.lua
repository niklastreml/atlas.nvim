local M = {}

local help = require("atlas.ui.popups.help")
local resolver = require("atlas.core.keymaps")
local utils = require("atlas.ui.shared.utils")

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
---@return table|nil
local function remove_item(action_id)
	local keys = resolver.resolve(action_id)
	if keys == nil then
		return nil
	end
	return { key = (#keys == 1 and keys[1] or keys) }
end

---@param buf integer
function M.register(buf)
	local items = {}

	utils.insert_if(items, item("ui.close", {
		desc = "Close panel",
		opts = { nowait = true, silent = true },
		callback = function()
			if help.is_open() then
				return
			end
			local layout_mod = require("atlas.ui.layout")
			local ui_st = require("atlas.ui.state")
			layout_mod.toggle_detail()
			if ui_st.on_panel_close then
				ui_st.on_panel_close()
			end
		end,
	}))

	utils.insert_if(items, item("ui.toggle_panel", {
		desc = "Toggle detail panel",
		callback = function()
			local layout_mod = require("atlas.ui.layout")
			local ui_st = require("atlas.ui.state")
			local was_open = layout_mod.win_id("detail") ~= nil
			layout_mod.toggle_detail()
			if was_open then
				if ui_st.on_panel_close then
					ui_st.on_panel_close()
				end
			else
				if ui_st.on_panel_open then
					ui_st.on_panel_open()
				end
			end
		end,
	}))

	utils.insert_if(items, item("ui.next_panel_tab", {
		desc = "Next panel tab",
		opts = { nowait = true },
		callback = function()
			local layout_mod = require("atlas.ui.layout")
			local ui_st = require("atlas.ui.state")
			if layout_mod.win_id("detail") ~= nil and ui_st.on_panel_next_tab then
				ui_st.on_panel_next_tab()
			end
		end,
	}))

	utils.insert_if(items, item("ui.previous_panel_tab", {
		desc = "Previous panel tab",
		opts = { nowait = true },
		callback = function()
			local layout_mod = require("atlas.ui.layout")
			local ui_st = require("atlas.ui.state")
			if layout_mod.win_id("detail") ~= nil and ui_st.on_panel_prev_tab then
				ui_st.on_panel_prev_tab()
			end
		end,
	}))

	M.remove(buf)
	help.register("Panel", items, { index = 211, buffer = buf })
end

---@param buf integer
function M.remove(buf)
	local items = {}
	utils.insert_if(items, remove_item("ui.close"))
	utils.insert_if(items, remove_item("ui.toggle_panel"))
	utils.insert_if(items, remove_item("ui.next_panel_tab"))
	utils.insert_if(items, remove_item("ui.previous_panel_tab"))

	help.remove("Panel", items, { buffer = buf })
end

return M
