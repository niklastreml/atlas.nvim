local M = {}

local layout = require("atlas.ui.layout")
local controller = require("atlas.bitbucketv2.panel.tabs.repo.branches.controller")

local mapped_buf = nil

function M.setup()
	local buf = layout.buf_id("detail")
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	if mapped_buf == buf then
		return
	end

	vim.keymap.set("n", "r", function()
		controller.refresh()
	end, {
		buffer = buf,
		silent = true,
		nowait = true,
		desc = "Refresh branches",
	})

	mapped_buf = buf
end

function M.teardown()
	if mapped_buf ~= nil and vim.api.nvim_buf_is_valid(mapped_buf) then
		pcall(vim.keymap.del, "n", "r", { buffer = mapped_buf })
	end
	mapped_buf = nil
end

return M
