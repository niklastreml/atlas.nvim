local M = {}

local layout = require("atlas.ui.layout")
local controller = require("atlas.jira.panel.tabs.overview.controller")
local help = require("atlas.ui.popups.help")

function M.setup()
	local buf = layout.buf_id("detail")
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	help.register("Jira", {
		{
			key = "m",
			desc = "Toggle adf/markdown",
			opts = { silent = true, nowait = true },
			callback = function()
				controller.toggle_view_mode()
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
		{ key = "m" },
	}, { buffer = buf })
end

return M
