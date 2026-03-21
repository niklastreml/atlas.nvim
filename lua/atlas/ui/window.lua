local M = {}
local state = require("atlas.ui.state")
local utils = require("atlas.ui.utils")
local highlights = require("atlas.ui.highlights")

function M.is_open()
	return state.win_id ~= nil and vim.api.nvim_win_is_valid(state.win_id)
end

function M.open()
	if M.is_open() then
		vim.api.nvim_set_current_win(state.win_id)
		return state.buf_id, state.win_id
	end

	highlights.setup()
	state.prev_win = vim.api.nvim_get_current_win()

	if state.buf_id == nil or not vim.api.nvim_buf_is_valid(state.buf_id) then
		state.buf_id = utils.create_buf("Atlas", "atlas")
	end

	vim.cmd("tabnew")
	state.tab_id = vim.api.nvim_get_current_tabpage()
	state.win_id = vim.api.nvim_get_current_win()

	local tab_buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_win_set_buf(state.win_id, state.buf_id)
	if tab_buf ~= state.buf_id and vim.api.nvim_buf_is_valid(tab_buf) then
		pcall(vim.api.nvim_buf_delete, tab_buf, { force = true })
	end

	utils.apply_win_config(state.win_id)

	--- TODO: Refactor somewhere else
	vim.keymap.set("n", "q", M.close, { buffer = state.buf_id, silent = true, nowait = true })
	return state.buf_id, state.win_id
end

function M.close()
	if not M.is_open() then
		return
	end

	if state.tab_id ~= nil and vim.api.nvim_tabpage_is_valid(state.tab_id) then
		local current_tab = vim.api.nvim_get_current_tabpage()
		if current_tab ~= state.tab_id then
			vim.api.nvim_set_current_tabpage(state.tab_id)
		end
		vim.cmd("tabclose")
	else
		vim.api.nvim_win_close(state.win_id, true)
	end

	state.win_id = nil
	state.tab_id = nil
	if state.prev_win ~= nil and vim.api.nvim_win_is_valid(state.prev_win) then
		vim.api.nvim_set_current_win(state.prev_win)
	end
	state.prev_win = nil
end

function M.resize()
	return
end

return M
