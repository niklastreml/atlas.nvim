local M = {}

local controller = require("atlas.jira.panel.tabs.overview.controller")
local renderer = require("atlas.jira.panel.tabs.overview.renderer")
local keymap = require("atlas.jira.panel.tabs.overview.keymap")

---@param issue JiraIssue|nil
---@param opts? { force_refresh?: boolean }
function M.activate(issue, opts)
	keymap.setup()
	controller.show(issue, opts)
	controller.move(0)

	local layout = require("atlas.ui.layout")
	local buf = layout.buf_id("detail")
	if buf ~= nil and vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })
		vim.api.nvim_set_option_value("syntax", "markdown", { buf = buf })
	end
end

function M.deactivate()
	keymap.teardown()
	controller.deactivate()

	local layout = require("atlas.ui.layout")
	local buf = layout.buf_id("detail")
	if buf ~= nil and vim.api.nvim_buf_is_valid(buf) then
		pcall(vim.treesitter.stop, buf)
		vim.api.nvim_set_option_value("syntax", "OFF", { buf = buf })
		vim.api.nvim_set_option_value("filetype", "", { buf = buf })
	end
end

---@param delta integer
function M.move_cursor(delta)
	controller.move(delta)
end

function M.refresh()
	controller.refresh()
end

---@return boolean
function M.is_loading()
	return controller.is_loading()
end

---@param width integer
---@return string[], table[], table|nil
function M.render(width)
	return renderer.render(width)
end

return M
