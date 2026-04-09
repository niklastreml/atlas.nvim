local M = {}
local layout = require("atlas.ui.layout")
local controller = require("atlas.jira.panel.tabs.comments.controller")
local help = require("atlas.ui.popups.help")

function M.setup()
	local buf = layout.buf_id("detail")
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	help.register("Jira", {
		{
			key = "c",
			desc = "Reply to comment",
			opts = { silent = true, nowait = true },
			callback = function()
				controller.reply_to_comment()
			end,
		},
		{
			key = "e",
			desc = "Edit comment",
			opts = { silent = true, nowait = true },
			callback = function()
				controller.edit_comment()
			end,
		},
		{
			key = "d",
			desc = "Delete comment",
			opts = { silent = true, nowait = true },
			callback = function()
				controller.delete_comment()
			end,
		},
		{
			key = "a",
			desc = "Add comment",
			opts = { silent = true, nowait = true },
			callback = function()
				controller.add_comment()
			end,
		},
	}, { index = 220, buffer = buf })
end

function M.teardown()
	local buf = layout.buf_id("detail")
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	help.remove("Jira", {
		{ key = "c" },
		{ key = "e" },
		{ key = "d" },
		{ key = "a" },
	}, { buffer = buf })
end

return M
