local M = {}
local state = require("atlas.ui.state")
local ui_utils = require("atlas.ui.utils")

function M.is_open()
	return state.win_id ~= nil and vim.api.nvim_win_is_valid(state.win_id)
end

function M.open(opts)
	opts = opts or {}

	if M.is_open() then
		vim.api.nvim_set_current_win(state.win_id)
		return state.buf_id, state.win_id
	end

	state.prev_win = vim.api.nvim_get_current_win()

	if state.buf_id == nil or not vim.api.nvim_buf_is_valid(state.buf_id) then
		state.buf_id = ui_utils.create_buf("Atlas", "atlas")
	end

	state.win_id = vim.api.nvim_open_win(state.buf_id, true, ui_utils.panel_win_config())
	ui_utils.apply_win_config(state.win_id)

	local title_hl = "AtlasTitleJira"
	if opts.provider == "bitbucket" then
		title_hl = "AtlasTitleBitbucket"
	elseif opts.provider == "github" then
		title_hl = "AtlasTitleGithub"
	end

	vim.api.nvim_set_option_value("winhighlight", "FloatTitle:" .. title_hl, { win = state.win_id })
	vim.api.nvim_win_set_config(
		state.win_id,
		vim.tbl_extend("force", ui_utils.panel_win_config(), {
			title = " " .. (opts.title or "Atlas") .. " ",
			title_pos = "center",
		})
	)

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

return M
