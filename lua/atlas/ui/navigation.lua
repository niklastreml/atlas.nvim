local M = {}

local ui_state = require("atlas.ui.state")

---@param view string|nil
---@param node table|nil
---@return boolean
local function is_selectable(view, node)
	if type(node) ~= "table" then
		return false
	end

	if view == "bitbucket" then
		return node.kind == "pr"
	end

	if view == "jira" then
		return node.kind == "issue"
	end

	return node.kind ~= nil
end

local function update_panel_selection(win)
	local panel = require("atlas.ui.panel")
	if not panel.is_open() then
		return
	end

	local line = vim.api.nvim_win_get_cursor(win)[1]
	local item = (ui_state.line_map or {})[line]

	local selection = nil
	if ui_state.current_view == "jira" then
		selection = require("atlas.jira").panel_selection_from_item(item)
	elseif ui_state.current_view == "bitbucket" then
		selection = require("atlas.bitbucket").panel_selection_from_item(item)
	end

	if selection ~= nil then
		panel.on_select(selection)
	end
end

---@return table|nil
function M.current_item()
	local layout = require("atlas.ui.layout")
	local win = layout.win_id("main")
	if win == nil or not vim.api.nvim_win_is_valid(win) then
		return nil
	end

	local line = vim.api.nvim_win_get_cursor(win)[1]
	return (ui_state.line_map or {})[line]
end

---@param direction "up"|"down"
function M.move_cursor(direction)
	local layout = require("atlas.ui.layout")
	local win = layout.win_id("main")
	local buf = layout.buf_id("main")
	if win == nil or not vim.api.nvim_win_is_valid(win) then
		return
	end
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	local current = vim.api.nvim_win_get_cursor(win)
	local line = current[1]
	local col = current[2]
	local max_line = vim.api.nvim_buf_line_count(buf)
	local step = direction == "up" and -1 or 1
	local view = ui_state.current_view
	local line_map = ui_state.line_map or {}
	local current_is_selectable = is_selectable(view, line_map[line])

	if current_is_selectable then
		for lnum = line + step, (direction == "up" and 1 or max_line), step do
			if is_selectable(view, line_map[lnum]) then
				vim.api.nvim_win_set_cursor(win, { lnum, col })
				update_panel_selection(win)
				return
			end
		end
	end

	local fallback = math.max(1, math.min(max_line, line + step))
	vim.api.nvim_win_set_cursor(win, { fallback, col })
	update_panel_selection(win)
end

function M.focus_first_item()
	local layout = require("atlas.ui.layout")
	local win = layout.win_id("main")
	local buf = layout.buf_id("main")
	if win == nil or not vim.api.nvim_win_is_valid(win) then
		return
	end
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	local view = ui_state.current_view
	local line_map = ui_state.line_map or {}
	local max_line = vim.api.nvim_buf_line_count(buf)

	for lnum = 1, max_line do
		if is_selectable(view, line_map[lnum]) then
			vim.api.nvim_win_set_cursor(win, { lnum, 0 })
			update_panel_selection(win)
			return
		end
	end
end

function M.focus_last_item()
	local layout = require("atlas.ui.layout")
	local win = layout.win_id("main")
	local buf = layout.buf_id("main")
	if win == nil or not vim.api.nvim_win_is_valid(win) then
		return
	end
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	local view = ui_state.current_view
	local line_map = ui_state.line_map or {}
	local max_line = vim.api.nvim_buf_line_count(buf)

	for lnum = max_line, 1, -1 do
		if is_selectable(view, line_map[lnum]) then
			vim.api.nvim_win_set_cursor(win, { lnum, 0 })
			update_panel_selection(win)
			return
		end
	end
end

return M
