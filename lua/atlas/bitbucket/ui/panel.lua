local M = {}

local ui_state = require("atlas.ui.state")

local panel_buf = nil
local panel_win = nil
local PANEL_RATIO = 0.4
local PANEL_MIN_WIDTH = 30

---@return boolean
function M.is_open()
	return panel_win ~= nil and vim.api.nvim_win_is_valid(panel_win)
end

local function close_if_invalid_parent()
	if panel_win ~= nil and not vim.api.nvim_win_is_valid(panel_win) then
		panel_win = nil
	end

	if ui_state.win_id == nil or not vim.api.nvim_win_is_valid(ui_state.win_id) then
		if M.is_open() then
			vim.api.nvim_win_close(panel_win, true)
		end
		panel_win = nil
	end
end

---@return integer
local function ensure_buf()
	if panel_buf ~= nil and vim.api.nvim_buf_is_valid(panel_buf) then
		return panel_buf
	end

	panel_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = panel_buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = panel_buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = panel_buf })
	vim.api.nvim_set_option_value("modifiable", false, { buf = panel_buf })

	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = panel_buf,
		once = true,
		callback = function()
			panel_buf = nil
			panel_win = nil
		end,
	})

	return panel_buf
end

---@return integer
local function target_width()
	local parent = ui_state.win_id
	if parent == nil or not vim.api.nvim_win_is_valid(parent) then
		return PANEL_MIN_WIDTH
	end

	local total_width = vim.api.nvim_win_get_width(parent)
	if M.is_open() then
		total_width = total_width + vim.api.nvim_win_get_width(panel_win)
	end

	return math.max(math.floor(total_width * PANEL_RATIO), PANEL_MIN_WIDTH)
end

local function configure_split_window(win)
	vim.api.nvim_set_option_value("number", false, { win = win })
	vim.api.nvim_set_option_value("relativenumber", false, { win = win })
	vim.api.nvim_set_option_value("signcolumn", "no", { win = win })
	vim.api.nvim_set_option_value("wrap", true, { win = win })
	vim.api.nvim_set_option_value("cursorline", false, { win = win })
	vim.api.nvim_set_option_value("winbar", " PR Details ", { win = win })
	vim.api.nvim_set_option_value("winhighlight", "Normal:Normal,NormalNC:Normal", { win = win })
	vim.api.nvim_win_set_width(win, target_width())
end

---@param pr table|nil
local function panel_lines(pr)
	if pr == nil then
		return {
			"No PR selected",
			"",
			"Move with j/k and press p to toggle this panel.",
		}
	end

	return {
		string.format("#%s %s", tostring(pr.id or "?"), pr.title or ""),
		"",
		"Author: " .. ((pr.author and pr.author.name) or "-"),
		"State: " .. (pr.state or "-"),
		"Draft: " .. (pr.is_draft and "yes" or "no"),
		"Repo: " .. ((pr.repo and pr.repo.name) or "-"),
		"Branches: " .. (pr.source_branch or "?") .. " -> " .. (pr.target_branch or "?"),
		"Comments: " .. tostring(pr.comments or 0),
		"Tasks: " .. tostring(pr.tasks or 0),
		"Created: " .. (pr.created_on or "-"),
		"Updated: " .. (pr.updated_on or "-"),
	}
end

---@param pr table|nil
function M.update(pr)
	close_if_invalid_parent()
	if not M.is_open() then
		return
	end

	local buf = ensure_buf()
	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, panel_lines(pr))
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

	vim.api.nvim_win_set_width(panel_win, target_width())
end

---@param pr table|nil
function M.open(pr)
	close_if_invalid_parent()
	if ui_state.win_id == nil or not vim.api.nvim_win_is_valid(ui_state.win_id) then
		return
	end

	local buf = ensure_buf()
	if not M.is_open() then
		local previous_win = vim.api.nvim_get_current_win()
		vim.api.nvim_set_current_win(ui_state.win_id)
		vim.cmd("botright vsplit")
		panel_win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(panel_win, buf)
		configure_split_window(panel_win)

		if ui_state.win_id ~= nil and vim.api.nvim_win_is_valid(ui_state.win_id) then
			vim.api.nvim_set_current_win(ui_state.win_id)
		elseif previous_win ~= nil and vim.api.nvim_win_is_valid(previous_win) then
			vim.api.nvim_set_current_win(previous_win)
		end
	else
		vim.api.nvim_win_set_buf(panel_win, buf)
		configure_split_window(panel_win)
	end

	M.update(pr)
end

function M.close()
	if M.is_open() then
		vim.api.nvim_win_close(panel_win, true)
	end
	panel_win = nil
end

---@param pr table|nil
function M.toggle(pr)
	if M.is_open() then
		M.close()
		return
	end
	M.open(pr)
end

return M
