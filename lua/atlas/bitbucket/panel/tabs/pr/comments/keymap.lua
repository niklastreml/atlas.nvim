local M = {}

local layout = require("atlas.ui.layout")
local controller = require("atlas.bitbucket.panel.tabs.pr.comments.controller")
local help = require("atlas.ui.popups.help")

function M.setup()
	local buf = layout.buf_id("detail")
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	local items = {
		{
			key = { "a", "i" },
			desc = "Add comment",
			opts = { silent = true, nowait = true },
			callback = function()
				controller.add_comment()
			end,
		},
		{
			key = "T",
			desc = "Add task",
			opts = { silent = true, nowait = true },
			callback = function()
				controller.add_task()
			end,
		},
		{
			key = "c",
			desc = "Reply to comment",
			opts = { silent = true, nowait = true },
			callback = function()
				controller.reply_to_comment()
			end,
		},
		{
			key = "t",
			desc = "Toggle task resolved",
			opts = { silent = true, nowait = true },
			callback = function()
				controller.toggle_task()
			end,
		},
		{
			key = "e",
			desc = "Edit comment/task",
			opts = { silent = true, nowait = true },
			callback = function()
				controller.edit_comment()
			end,
		},
		{
			key = "d",
			desc = "Delete comment/task",
			opts = { silent = true, nowait = true },
			callback = function()
				controller.delete_comment()
			end,
		},
	}

	help.register("Bitbucket", items, { index = 220, buffer = buf })
end

function M.teardown()
	local buf = layout.buf_id("detail")
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	help.remove("Bitbucket", {
		{ key = "a" },
		{ key = "T" },
		{ key = "c" },
		{ key = "t" },
		{ key = "e" },
		{ key = "d" },
	}, { buffer = buf })
end

return M
