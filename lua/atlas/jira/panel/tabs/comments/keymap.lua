local M = {}
local layout = require("atlas.ui.layout")
local controller = require("atlas.jira.panel.tabs.comments.controller")

function M.setup()
	local buf = layout.buf_id("detail")
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	vim.keymap.set("n", "c", function()
		controller.reply_to_comment()
	end, {
		buffer = buf,
		silent = true,
		nowait = true,
		desc = "Reply to comment",
	})

	vim.keymap.set("n", "e", function()
		controller.edit_comment()
	end, {
		buffer = buf,
		silent = true,
		nowait = true,
		desc = "Edit comment",
	})

	vim.keymap.set("n", "d", function()
		controller.delete_comment()
	end, {
		buffer = buf,
		silent = true,
		nowait = true,
		desc = "Delete comment",
	})

	vim.keymap.set("n", "a", function()
		controller.add_comment()
	end, {
		buffer = buf,
		silent = true,
		nowait = true,
		desc = "Add comment",
	})
end

function M.teardown()
	local buf = layout.buf_id("detail")
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	pcall(vim.keymap.del, "n", "c", { buffer = buf })
	pcall(vim.keymap.del, "n", "e", { buffer = buf })
	pcall(vim.keymap.del, "n", "d", { buffer = buf })
	pcall(vim.keymap.del, "n", "a", { buffer = buf })
end

return M
