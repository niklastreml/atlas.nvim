local M = {}

local help = require("atlas.ui.popups.help")
local ui_state = require("atlas.ui.main.state")

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

	if view == "github" then
		return node.kind == "pr"
	end

	return node.kind ~= nil
end

local function update_panel_selection(win)
	local panel = require("atlas.ui.panel")
	if not panel.is_open() then
		return
	end

	local line = vim.api.nvim_win_get_cursor(win)[1]
	panel.on_select(ui_state.current_view, (ui_state.line_map or {})[line])
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

	for lnum = line + step, (direction == "up" and 1 or max_line), step do
		if is_selectable(view, line_map[lnum]) then
			vim.api.nvim_win_set_cursor(win, { lnum, col })
			update_panel_selection(win)
			return
		end
	end

	if is_selectable(view, line_map[line]) then
		return
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

---@param buf integer|nil
function M.register_keys(buf)
	local layout = require("atlas.ui.layout")
	local target_buf = buf or layout.buf_id("main")
	if target_buf == nil or not vim.api.nvim_buf_is_valid(target_buf) then
		return
	end

	local items = {
		{
			key = "j",
			desc = "Next item",
			callback = function()
				M.move_cursor("down")
			end,
		},
		{
			key = "k",
			desc = "Previous item",
			callback = function()
				M.move_cursor("up")
			end,
		},
		{
			key = "p",
			desc = "Toggle detail pane",
			callback = function()
				require("atlas.ui.panel").toggle()
			end,
		},
		{
			key = "[",
			desc = "Previous panel tab",
			callback = function()
				if ui_state.current_view ~= "bitbucket" then
					return
				end
				local panel = require("atlas.ui.panel")
				if not panel.is_open() then
					return
				end
				require("atlas.bitbucket.ui.panel.controller").prev_tab()
			end,
		},
		{
			key = "]",
			desc = "Next panel tab",
			callback = function()
				if ui_state.current_view ~= "bitbucket" then
					return
				end
				local panel = require("atlas.ui.panel")
				if not panel.is_open() then
					return
				end
				require("atlas.bitbucket.ui.panel.controller").next_tab()
			end,
		},
	}

	for _, item in ipairs(items) do
		help.unregister_key("Navigation", item.key, { buf = target_buf })
	end

	help.register_keys("Navigation", items, {
		index = 210,
		buf = target_buf,
	})
end

return M
