local M = {}

local controller = require("atlas.bitbucket.panel.tabs.pr.files.controller")
local renderer = require("atlas.bitbucket.panel.tabs.pr.files.renderer")
local keymap = require("atlas.bitbucket.panel.tabs.pr.files.keymap")

---@param pr BitbucketPR|nil
function M.activate(pr)
	keymap.setup()
	controller.show(pr)
	controller.move(0)

	local layout = require("atlas.ui.layout")

	local buf = layout.buf_id("detail")
	if buf ~= nil and vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_set_option_value("filetype", "diff", { buf = buf })
		vim.api.nvim_set_option_value("syntax", "OFF", { buf = buf })
		pcall(vim.treesitter.stop, buf)
	end

	local win = layout.win_id("detail")
	if win ~= nil and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_set_option_value("wrap", false, { win = win })
	end
end

function M.deactivate()
	keymap.teardown()
	controller.deactivate()

	local layout = require("atlas.ui.layout")

	local buf = layout.buf_id("detail")
	if buf ~= nil and vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_set_option_value("filetype", "", { buf = buf })
	end

	local win = layout.win_id("detail")
	if win ~= nil and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_set_option_value("wrap", true, { win = win })
		vim.api.nvim_set_option_value("scrollbind", false, { win = win })
		vim.api.nvim_set_option_value("cursorbind", false, { win = win })
	end
end

---@param delta integer
function M.move_cursor(delta)
	controller.move(delta)
end

---@param width integer
---@return string[], table[], table|nil
function M.render(width)
	return renderer.render(width)
end

return M
