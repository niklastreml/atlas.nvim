local M = {}

local help = require("atlas.ui.popups.help")
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

	if view == "github" then
		return node.kind == "pr"
	end

	return node.kind ~= nil
end

---@param direction "up"|"down"
function M.move_cursor(direction)
	local win = ui_state.win_id
	local buf = ui_state.buf_id
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
			return
		end
	end

	if is_selectable(view, line_map[line]) then
		return
	end

	local fallback = math.max(1, math.min(max_line, line + step))
	vim.api.nvim_win_set_cursor(win, { fallback, col })
end

function M.focus_first_item()
	local win = ui_state.win_id
	local buf = ui_state.buf_id
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
			return
		end
	end
end

---@param buf integer|nil
function M.register_keys(buf)
	local target_buf = buf or ui_state.buf_id
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
