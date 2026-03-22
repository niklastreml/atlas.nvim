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
	vim.api.nvim_set_option_value("syntax", "OFF", { buf = buf })
	pcall(vim.treesitter.stop, buf)
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

function M.relative_time(iso)
	if type(iso) ~= "string" or iso == "" then
		return "-"
	end

	local base = iso:match("^(%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d)")
	if not base then
		return "-"
	end

	local then_epoch = vim.fn.strptime("%Y-%m-%dT%H:%M:%S", base)
	if then_epoch <= 0 then
		return "-"
	end

	local delta = os.time() - then_epoch
	if delta < 0 then
		delta = 0
	end

	if delta < 5 then
		return "just now"
	end
	if delta < 60 then
		return string.format("%ds ago", delta)
	end

	local minutes = math.floor(delta / 60)
	if minutes < 60 then
		return string.format("%dm ago", minutes)
	end

	local hours = math.floor(minutes / 60)
	if hours < 24 then
		return string.format("%dh ago", hours)
	end

	local days = math.floor(hours / 24)
	if days < 7 then
		return string.format("%dd ago", days)
	end

	local weeks = math.floor(days / 7)
	if weeks < 5 then
		return string.format("%dw ago", weeks)
	end

	local months = math.floor(days / 30)
	if months < 12 then
		return string.format("%dmo ago", months)
	end

	local years = math.floor(days / 365)
	return string.format("%dy ago", years)
end

return M
