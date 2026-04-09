local M = {}

local layout = require("atlas.ui.layout")
local controller = require("atlas.bitbucket.panel.tabs.pr.files.controller")
local help = require("atlas.ui.popups.help")

local mapped_buf = nil

function M.setup()
	local buf = layout.buf_id("detail")
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	if mapped_buf == buf then
		return
	end

	help.register("Bitbucket", {
		{
			key = "za",
			desc = "Toggle hunk fold",
			opts = { silent = true, nowait = true },
			callback = function()
				controller.toggle_fold()
			end,
		},
		{
			key = "]h",
			desc = "Next hunk",
			opts = { silent = true, nowait = true },
			callback = function()
				controller.jump_hunk(1)
			end,
		},
		{
			key = "[h",
			desc = "Previous hunk",
			opts = { silent = true, nowait = true },
			callback = function()
				controller.jump_hunk(-1)
			end,
		},
	}, { index = 220, buffer = buf })

	mapped_buf = buf
end

function M.teardown()
	if mapped_buf ~= nil and vim.api.nvim_buf_is_valid(mapped_buf) then
		help.remove("Bitbucket", {
			{ key = "za" },
			{ key = "]h" },
			{ key = "[h" },
		}, { buffer = mapped_buf })
	end
	mapped_buf = nil
end

return M
