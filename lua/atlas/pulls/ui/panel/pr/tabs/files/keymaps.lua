local M = {}

local help = require("atlas.ui.popups.help")
local resolver = require("atlas.core.keymaps")
local utils = require("atlas.ui.shared.utils")
local layout = require("atlas.ui.layout")

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
---@param refresh fun()
function M.setup(buf, refresh)
	local tab = require("atlas.pulls.ui.panel.pr.tabs.files")
	local panel_state = require("atlas.pulls.ui.panel.pr.state")

	local function cursor_entry()
		local win = layout.win_id("detail")
		if win == nil or not vim.api.nvim_win_is_valid(win) then
			return nil
		end
		local lnum = vim.api.nvim_win_get_cursor(win)[1]
		return (panel_state.line_map or {})[lnum]
	end

	local items = {}
	utils.insert_if(items, item("pulls.pr_files_toggle_fold", {
		desc = "Toggle hunk fold",
		opts = { nowait = true, silent = true },
		callback = function()
			local entry = cursor_entry()
			if entry then
				tab.toggle_hunk(entry)
				refresh()
			end
		end,
	}))
	utils.insert_if(items, item("pulls.pr_files_next_hunk", {
		desc = "Next hunk",
		opts = { nowait = true, silent = true },
		callback = function()
			tab.jump_hunk("next")
		end,
	}))
	utils.insert_if(items, item("pulls.pr_files_previous_hunk", {
		desc = "Previous hunk",
		opts = { nowait = true, silent = true },
		callback = function()
			tab.jump_hunk("prev")
		end,
	}))

	help.register("Panel", items, { index = 212, buffer = buf })
end

---@param buf integer
function M.teardown(buf)
	local items = {}
	utils.insert_if(items, remove_item("pulls.pr_files_toggle_fold"))
	utils.insert_if(items, remove_item("pulls.pr_files_next_hunk"))
	utils.insert_if(items, remove_item("pulls.pr_files_previous_hunk"))
	help.remove("Panel", items, { buffer = buf })
end

return M
