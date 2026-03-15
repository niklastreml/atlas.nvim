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

	local win_cfg = utils.panel_win_config()
	state.win_id = vim.api.nvim_open_win(state.buf_id, true, win_cfg)
	utils.apply_win_config(state.win_id)

	--- TODO: Refactor somewhere else
	vim.keymap.set("n", "q", M.close, { buffer = state.buf_id, silent = true, nowait = true })
	return state.buf_id, state.win_id
end

function M.close()
	if not M.is_open() then
		return
	end

	vim.api.nvim_win_close(state.win_id, true)
	state.win_id = nil
	if state.prev_win ~= nil and vim.api.nvim_win_is_valid(state.prev_win) then
		vim.api.nvim_set_current_win(state.prev_win)
	end
	state.prev_win = nil
end

function M.resize()
	if not M.is_open() then
		return
	end

	local cfg = utils.panel_win_config()
	vim.api.nvim_win_set_config(state.win_id, cfg)
end

return M
