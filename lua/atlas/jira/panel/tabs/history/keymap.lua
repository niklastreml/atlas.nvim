local M = {}

local layout = require("atlas.ui.layout")
local controller = require("atlas.jira.panel.tabs.history.controller")

function M.setup()
	local buf = layout.buf_id("detail")
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	vim.keymap.set("n", "r", function()
		controller.refresh()
	end, {
		buffer = buf,
		silent = true,
		nowait = true,
		desc = "Refresh history",
	})
end

function M.teardown()
	local buf = layout.buf_id("detail")
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	pcall(vim.keymap.del, "n", "r", { buffer = buf })
end

return M
