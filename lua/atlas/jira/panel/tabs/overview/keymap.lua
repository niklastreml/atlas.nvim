local M = {}

local layout = require("atlas.ui.layout")
local controller = require("atlas.jira.panel.tabs.overview.controller")

function M.setup()
	local buf = layout.buf_id("detail")
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	vim.keymap.set("n", "m", function()
		controller.toggle_view_mode()
	end, {
		buffer = buf,
		silent = true,
		nowait = true,
		desc = "Toggle adf/markdown",
	})

	vim.keymap.set("n", "r", function()
		controller.refresh()
	end, {
		buffer = buf,
		silent = true,
		nowait = true,
		desc = "Refresh overview",
	})
end

function M.teardown()
	local buf = layout.buf_id("detail")
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	pcall(vim.keymap.del, "n", "m", { buffer = buf })
	pcall(vim.keymap.del, "n", "r", { buffer = buf })
	pcall(vim.keymap.del, "n", "e", { buffer = buf })
end

return M
