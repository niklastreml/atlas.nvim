local M = {}

local layout = require("atlas.ui.layout")
local state = require("atlas.ui.panel.state")
local ui_state = require("atlas.ui.main.state")

local function current_item()
	local win = layout.win_id("main")
	if win == nil or not vim.api.nvim_win_is_valid(win) then
		return nil
	end


	local line = vim.api.nvim_win_get_cursor(win)[1]
	return (ui_state.line_map or {})[line]
end

function M.open()
	if M.is_open() then
		return
	end

	layout.toggle_detail()
	state.open = M.is_open()
	if state.open then
		M.on_select(ui_state.current_view, current_item())
	end
end

function M.close()
	if not M.is_open() then
		return
	end

	layout.toggle_detail()
	state.open = false
end

function M.toggle()
	if M.is_open() then
		M.close()
		return
	end
	M.open()
end

function M.is_open()
	return layout.win_id("detail") ~= nil
end

---@param provider "bitbucket"|"jira"
---@param item table|nil
function M.on_select(provider, item)
	state.set_selection(provider, item)
	if not M.is_open() then
		return
	end

	if provider == "bitbucket" then
		require("atlas.bitbucket.ui.panel.controller").on_select(item)
		return
	end

	require("atlas.ui.panel.renderer").render(provider)
end

function M.refresh()
	if not M.is_open() then
		return
	end
	require("atlas.ui.panel.renderer").render(state.active_provider or ui_state.current_view)
end

return M
