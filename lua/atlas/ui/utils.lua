local M = {}

function M.panel_win_config()
	local total_w = vim.o.columns
	local total_h = vim.o.lines
	local width = math.floor(total_w * 0.9)
	local height = math.floor(total_h * 0.9)
	local row = math.floor((total_h - height) / 2)
	local col = math.floor((total_w - width) / 2)

	return {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "none",
		title_pos = "center",
		title = "Atlas",
		zindex = 100,
	}
end

function M.create_buf(name, filetype)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, name)
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "hide", { buf = buf })
	vim.api.nvim_set_option_value("filetype", filetype, { buf = buf })
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
	return buf
end

function M.apply_win_config(win)
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

function M.append_block(lines, spans, block)
	local base = #lines
	for _, line in ipairs(block.lines or {}) do
		table.insert(lines, line)
	end
	for _, span in ipairs(block.highlights or {}) do
		table.insert(spans, {
			line = base + span.line,
			start_col = span.start_col,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end
end

return M
