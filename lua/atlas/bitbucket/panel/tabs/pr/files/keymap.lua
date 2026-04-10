local M = {}

local layout = require("atlas.ui.layout")
local controller = require("atlas.bitbucket.panel.tabs.pr.files.controller")
local help = require("atlas.ui.popups.help")
local resolver = require("atlas.core.keymaps")
local utils = require("atlas.utils")

local mapped_buf = nil

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

function M.setup()
	local buf = layout.buf_id("detail")
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	if mapped_buf == buf then
		return
	end

	local items = {}
	utils.insert_if(items, item("bitbucket.pr_files_toggle_fold", {
			desc = "Toggle hunk fold",
			opts = { silent = true, nowait = true },
			callback = function()
				controller.toggle_fold()
			end,
	}))
	utils.insert_if(items, item("bitbucket.pr_files_next_hunk", {
			desc = "Next hunk",
			opts = { silent = true, nowait = true },
			callback = function()
				controller.jump_hunk(1)
			end,
	}))
	utils.insert_if(items, item("bitbucket.pr_files_previous_hunk", {
			desc = "Previous hunk",
			opts = { silent = true, nowait = true },
			callback = function()
				controller.jump_hunk(-1)
			end,
	}))
	help.register("Bitbucket", items, { index = 220, buffer = buf })

	mapped_buf = buf
end

function M.teardown()
	if mapped_buf ~= nil and vim.api.nvim_buf_is_valid(mapped_buf) then
		local items = {}
		utils.insert_if(items, remove_item("bitbucket.pr_files_toggle_fold"))
		utils.insert_if(items, remove_item("bitbucket.pr_files_next_hunk"))
		utils.insert_if(items, remove_item("bitbucket.pr_files_previous_hunk"))
		help.remove("Bitbucket", items, { buffer = mapped_buf })
	end
	mapped_buf = nil
end

return M
