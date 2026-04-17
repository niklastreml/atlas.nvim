local M = {}

---@param win integer|nil
---@return boolean
function M.valid(win)
	return win ~= nil and vim.api.nvim_win_is_valid(win)
end

---@param anchor integer
---@param split_cmd string
---@param buf integer
---@param apply_opts fun(win: integer)
---@return integer
function M.create(anchor, split_cmd, buf, apply_opts)
	local prev = vim.api.nvim_get_current_win()
	vim.api.nvim_set_current_win(anchor)
	vim.cmd(split_cmd)
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, buf)
	apply_opts(win)
	if M.valid(prev) then
		vim.api.nvim_set_current_win(prev)
	end
	return win
end

---@param win integer
function M.apply_main_opts(win)
	vim.api.nvim_set_option_value("number", false, { win = win })
	vim.api.nvim_set_option_value("relativenumber", false, { win = win })
	vim.api.nvim_set_option_value("signcolumn", "no", { win = win })
	vim.api.nvim_set_option_value("statuscolumn", "", { win = win })
	vim.api.nvim_set_option_value("foldcolumn", "0", { win = win })
	vim.api.nvim_set_option_value("wrap", false, { win = win })
	vim.api.nvim_set_option_value("cursorline", true, { win = win })
	vim.api.nvim_set_option_value("scrollbind", false, { win = win })
	vim.api.nvim_set_option_value("cursorbind", false, { win = win })
	vim.api.nvim_set_option_value("diff", false, { win = win })
	vim.api.nvim_set_option_value("winbar", " ", { win = win })
	vim.api.nvim_set_option_value("statusline", " ", { win = win })
	vim.api.nvim_set_option_value(
		"winhighlight",
		"Normal:Normal,NormalFloat:Normal,FloatBorder:FloatBorder,CursorLine:CursorLine",
		{ win = win }
	)
end

---@param win integer
function M.apply_footer_opts(win)
	vim.api.nvim_set_option_value("number", false, { win = win })
	vim.api.nvim_set_option_value("relativenumber", false, { win = win })
	vim.api.nvim_set_option_value("signcolumn", "no", { win = win })
	vim.api.nvim_set_option_value("statuscolumn", "", { win = win })
	vim.api.nvim_set_option_value("foldcolumn", "0", { win = win })
	vim.api.nvim_set_option_value("wrap", false, { win = win })
	vim.api.nvim_set_option_value("cursorline", false, { win = win })
	vim.api.nvim_set_option_value("winbar", " ", { win = win })
	vim.api.nvim_set_option_value("statusline", " ", { win = win })
	vim.api.nvim_set_option_value("winfixheight", true, { win = win })
end

---@param win integer
function M.apply_detail_opts(win)
	vim.api.nvim_set_option_value("number", false, { win = win })
	vim.api.nvim_set_option_value("relativenumber", false, { win = win })
	vim.api.nvim_set_option_value("signcolumn", "no", { win = win })
	vim.api.nvim_set_option_value("statuscolumn", "", { win = win })
	vim.api.nvim_set_option_value("foldcolumn", "0", { win = win })
	vim.api.nvim_set_option_value("wrap", true, { win = win })
	vim.api.nvim_set_option_value("cursorline", false, { win = win })
	vim.api.nvim_set_option_value("scrollbind", false, { win = win })
	vim.api.nvim_set_option_value("cursorbind", false, { win = win })
	vim.api.nvim_set_option_value("diff", false, { win = win })
	vim.api.nvim_set_option_value("winbar", " ", { win = win })
	vim.api.nvim_set_option_value("statusline", " ", { win = win })
	vim.api.nvim_set_option_value("winfixwidth", false, { win = win })
end

return M
