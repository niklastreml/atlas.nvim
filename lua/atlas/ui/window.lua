local M = {}
local state = require("atlas.ui.state")
local highlights = require("atlas.ui.highlights")

local function hide_chrome()
	-- TODO: This is a bit hacky, we should probably find a better way to handle this
	vim.o.laststatus = 0
	vim.o.ruler = false
	vim.o.showcmd = false
end

local function create_buf(name, filetype)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, name)
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "hide", { buf = buf })
	vim.api.nvim_set_option_value("filetype", filetype, { buf = buf })
	vim.api.nvim_set_option_value("syntax", "OFF", { buf = buf })
	pcall(vim.treesitter.stop, buf)
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
	return buf
end

local function apply_win_config(win)
	vim.api.nvim_set_option_value("number", false, { win = win })
	vim.api.nvim_set_option_value("relativenumber", false, { win = win })
	vim.api.nvim_set_option_value("signcolumn", "no", { win = win })
	vim.api.nvim_set_option_value("statuscolumn", "", { win = win })
	vim.api.nvim_set_option_value("foldcolumn", "0", { win = win })
	vim.api.nvim_set_option_value("wrap", false, { win = win })
	vim.api.nvim_set_option_value("cursorline", true, { win = win })
	vim.api.nvim_set_option_value("winbar", "", { win = win })
	vim.api.nvim_set_option_value("statusline", "", { win = win })
	vim.api.nvim_set_option_value(
		"winhighlight",
		"Normal:Normal,NormalFloat:Normal,FloatBorder:FloatBorder,CursorLine:CursorLine",
		{ win = win }
	)
end

function M.is_open()
	return state.win_id ~= nil and vim.api.nvim_win_is_valid(state.win_id)
end

function M.open()
	if M.is_open() then
		vim.api.nvim_set_current_win(state.win_id)
		hide_chrome()
		return state.buf_id, state.win_id
	end

	highlights.setup()
	state.prev_win = vim.api.nvim_get_current_win()
	state.prev_laststatus = vim.o.laststatus
	state.prev_ruler = vim.o.ruler
	state.prev_showcmd = vim.o.showcmd

	if state.buf_id == nil or not vim.api.nvim_buf_is_valid(state.buf_id) then
		state.buf_id = create_buf("Atlas", "atlas")
	end

	vim.cmd("tabnew")
	state.tab_id = vim.api.nvim_get_current_tabpage()
	state.win_id = vim.api.nvim_get_current_win()

	local tab_buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_win_set_buf(state.win_id, state.buf_id)
	if tab_buf ~= state.buf_id and vim.api.nvim_buf_is_valid(tab_buf) then
		pcall(vim.api.nvim_buf_delete, tab_buf, { force = true })
	end

	apply_win_config(state.win_id)
	hide_chrome()

	vim.schedule(function()
		if M.is_open() then
			hide_chrome()
		end
	end)

	vim.keymap.set("n", "q", M.close, { buffer = state.buf_id, silent = true, nowait = true })
	return state.buf_id, state.win_id
end

function M.close()
	if not M.is_open() then
		return
	end

	pcall(function()
		require("atlas.ui.components.spinner").stop()
	end)

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
	if state.prev_laststatus ~= nil then
		vim.o.laststatus = state.prev_laststatus
	end
	if state.prev_ruler ~= nil then
		vim.o.ruler = state.prev_ruler
	end
	if state.prev_showcmd ~= nil then
		vim.o.showcmd = state.prev_showcmd
	end
	state.prev_laststatus = nil
	state.prev_ruler = nil
	state.prev_showcmd = nil
	if state.prev_win ~= nil and vim.api.nvim_win_is_valid(state.prev_win) then
		vim.api.nvim_set_current_win(state.prev_win)
	end
	state.prev_win = nil
end

return M
