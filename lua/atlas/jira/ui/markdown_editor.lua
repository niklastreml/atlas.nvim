local M = {}

local footer = require("atlas.ui.components.footer")

---@class JiraMarkdownEditorOptions
---@field key string
---@field title string|nil
---@field initial_text string|nil
---@field width_ratio number|nil
---@field height_ratio number|nil
---@field on_save fun(text: string)|nil
---@field on_cancel fun()|nil

---@param opts JiraMarkdownEditorOptions
---@return integer|nil, integer|nil
function M.open(opts)
	if type(opts) ~= "table" then
		return nil, nil
	end

	local key = tostring(opts.key or "")
	if key == "" then
		footer.notify("warn", "Missing editor key")
		return nil, nil
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_option_value("buftype", "acwrite", { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
	vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })
	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })

	local name = string.format("atlas://jira/editor/%s.md", key)
	pcall(vim.api.nvim_buf_set_name, buf, name)

	local lines = vim.split(tostring(opts.initial_text or ""), "\n", { plain = true })
	if #lines == 0 then
		lines = { "" }
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modified", false, { buf = buf })

	local width_ratio = tonumber(opts.width_ratio) or 0.8
	local height_ratio = tonumber(opts.height_ratio) or 0.8
	local min_width = 80
	local min_height = 12

	local width = math.max(math.floor(vim.o.columns * width_ratio), min_width)
	local height = math.max(math.floor(vim.o.lines * height_ratio), min_height)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		style = "minimal",
		border = "rounded",
		width = width,
		height = height,
		row = row,
		col = col,
		title = opts.title,
		title_pos = "center",
		footer = " q quit | :w save ",
		footer_pos = "center",
	})

	vim.api.nvim_set_option_value("number", false, { win = win })
	vim.api.nvim_set_option_value("relativenumber", false, { win = win })
	vim.api.nvim_set_option_value("wrap", true, { win = win })
	vim.api.nvim_set_option_value("cursorline", false, { win = win })

	vim.keymap.set("n", "q", function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end, { buffer = buf, silent = true, nowait = true })

	local did_save = false

	vim.api.nvim_create_autocmd("BufWriteCmd", {
		buffer = buf,
		callback = function()
			local body = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
			did_save = true
			vim.api.nvim_set_option_value("modified", false, { buf = buf })
			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_close(win, true)
			end

			if type(opts.on_save) == "function" then
				opts.on_save(body)
			end
		end,
	})

	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = buf,
		callback = function()
			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_set_option_value("modified", false, { buf = buf })
			end
		end,
	})

	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = buf,
		once = true,
		callback = function()
			if not did_save and type(opts.on_cancel) == "function" then
				opts.on_cancel()
			end
		end,
	})

	return buf, win
end

return M
