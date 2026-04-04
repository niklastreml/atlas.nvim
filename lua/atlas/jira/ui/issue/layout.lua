local M = {}

local function valid_win(win)
	return win ~= nil and vim.api.nvim_win_is_valid(win)
end

local function valid_buf(buf)
	return buf ~= nil and vim.api.nvim_buf_is_valid(buf)
end

---@param kind "win"|"buf"
---@param id integer|nil
local function close_target(kind, id)
	if kind == "win" then
		if valid_win(id) then
			vim.api.nvim_win_close(id, true)
		end
		return
	end

	if valid_buf(id) then
		vim.api.nvim_buf_delete(id, { force = true })
	end
end

---@param layout IssueWindows
function M.close(layout)
	close_target("win", layout.desc_win)
	close_target("win", layout.meta_win)
	close_target("win", layout.title_win)
	close_target("win", layout.container_win)

	close_target("buf", layout.desc_buf)
	close_target("buf", layout.meta_buf)
	close_target("buf", layout.title_buf)
	close_target("buf", layout.container_buf)
end

---@param opts { buftype: string, modifiable: boolean, name: string, filetype?: string }
---@return integer
local function create_issue_buffer(opts)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_option_value("buftype", opts.buftype, { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
	if opts.filetype then
		vim.api.nvim_set_option_value("filetype", opts.filetype, { buf = buf })
	end
	vim.api.nvim_set_option_value("modifiable", opts.modifiable, { buf = buf })
	pcall(vim.api.nvim_buf_set_name, buf, opts.name)
	return buf
end

---@param opts { buffer: integer, enter: boolean, parent: integer, width: integer, height: integer, row: integer, col: integer, focusable?: boolean, wrap: boolean, winbar?: string }
---@return integer
local function open_issue_window(opts)
	local win = vim.api.nvim_open_win(opts.buffer, opts.enter, {
		relative = "win",
		win = opts.parent,
		width = opts.width,
		height = opts.height,
		row = opts.row,
		col = opts.col,
		style = "minimal",
		border = "none",
		focusable = opts.focusable,
	})

	vim.api.nvim_set_option_value("number", false, { win = win })
	vim.api.nvim_set_option_value("relativenumber", false, { win = win })
	vim.api.nvim_set_option_value("cursorline", false, { win = win })
	vim.api.nvim_set_option_value("wrap", opts.wrap, { win = win })

	if opts.winbar then
		vim.api.nvim_set_option_value("winbar", opts.winbar, { win = win })
	end

	return win
end

---@param state IssueState
function M.open_layout(state)
	local width = math.max(math.floor(vim.o.columns * 0.6), 60)
	local height = math.max(math.floor(vim.o.lines * 0.6), 20)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local inner_width = width - 2
	local content_width = inner_width - 4
	local content_col = 2

	state.content_width = content_width

	state.layout.container_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = state.layout.container_buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = state.layout.container_buf })

	state.layout.container_win = vim.api.nvim_open_win(state.layout.container_buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		focusable = false,
		mouse = false,
		title = " Create Issue ",
		title_pos = "center",
		footer = " q/:q close | :w create | ga assignee | gr reporter | gt issue type | m toggle ADF preview ",
		footer_pos = "center",
	})
	vim.api.nvim_set_option_value("wrap", false, { win = state.layout.container_win })

	state.layout.title_buf = create_issue_buffer({
		buftype = "acwrite",
		modifiable = true,
		name = "atlas://jira/create/title",
	})

	state.layout.meta_buf = create_issue_buffer({
		buftype = "nofile",
		modifiable = false,
		name = "atlas://jira/create/meta",
	})

	state.layout.desc_buf = create_issue_buffer({
		buftype = "acwrite",
		modifiable = true,
		name = "atlas://jira/create/description.md",
		filetype = "markdown",
	})

	vim.api.nvim_buf_set_lines(state.layout.title_buf, 0, -1, false, { tostring(state.fields.summary or "") })
	local initial_desc = type(state.fields.description) == "string" and state.fields.description or ""
	vim.api.nvim_buf_set_lines(state.layout.desc_buf, 0, -1, false, vim.split(initial_desc, "\n", { plain = true }))

	local separator_line = string.rep("─", inner_width)
	vim.api.nvim_buf_set_lines(state.layout.container_buf, 0, -1, false, vim.fn["repeat"]({ "" }, height))

	state.layout.title_win = open_issue_window({
		buffer = state.layout.title_buf,
		enter = true,
		parent = state.layout.container_win,
		width = content_width,
		height = 2,
		row = 0,
		col = content_col,
		wrap = false,
		winbar = "Summary",
	})

	state.layout.meta_win = open_issue_window({
		buffer = state.layout.meta_buf,
		enter = false,
		parent = state.layout.container_win,
		width = content_width,
		height = 2,
		row = 4,
		col = content_col,
		focusable = false,
		wrap = false,
	})

	state.layout.desc_win = open_issue_window({
		buffer = state.layout.desc_buf,
		enter = false,
		parent = state.layout.container_win,
		width = content_width,
		height = math.max(1, height - 8),
		row = 7,
		col = content_col,
		wrap = true,
		winbar = "Description",
	})

	vim.api.nvim_buf_set_lines(state.layout.container_buf, 3, 4, false, { separator_line })
	vim.api.nvim_buf_set_lines(state.layout.container_buf, 6, 7, false, { separator_line })
end

---@param state IssueState
---@param actions { confirm_close: fun(), toggle_preview: fun(), show_assignee_picker: fun(), show_reporter_picker: fun(), show_issue_type_picker: fun() }
function M.setup_keymaps(state, actions)
	local keymap_opts = { silent = true, nowait = true }

	if valid_buf(state.layout.title_buf) then
		vim.keymap.set(
			"n",
			"q",
			actions.confirm_close,
			vim.tbl_extend("force", keymap_opts, { buffer = state.layout.title_buf })
		)
		vim.keymap.set("n", "<CR>", function()
			if valid_win(state.layout.desc_win) then
				vim.api.nvim_set_current_win(state.layout.desc_win)
			end
		end, vim.tbl_extend("force", keymap_opts, { buffer = state.layout.title_buf }))
		vim.keymap.set("n", "<Tab>", function()
			if valid_win(state.layout.desc_win) then
				vim.api.nvim_set_current_win(state.layout.desc_win)
			end
		end, vim.tbl_extend("force", keymap_opts, { buffer = state.layout.title_buf }))
		vim.keymap.set(
			"n",
			"ga",
			actions.show_assignee_picker,
			vim.tbl_extend("force", keymap_opts, { buffer = state.layout.title_buf })
		)
		vim.keymap.set(
			"n",
			"gr",
			actions.show_reporter_picker,
			vim.tbl_extend("force", keymap_opts, { buffer = state.layout.title_buf })
		)
		vim.keymap.set(
			"n",
			"gt",
			actions.show_issue_type_picker,
			vim.tbl_extend("force", keymap_opts, { buffer = state.layout.title_buf })
		)
		vim.keymap.set("i", "<CR>", function()
			vim.cmd("stopinsert")
			if valid_win(state.layout.desc_win) then
				vim.api.nvim_set_current_win(state.layout.desc_win)
			end
		end, vim.tbl_extend("force", keymap_opts, { buffer = state.layout.title_buf }))
		vim.keymap.set("i", "<Tab>", function()
			vim.cmd("stopinsert")
			if valid_win(state.layout.desc_win) then
				vim.api.nvim_set_current_win(state.layout.desc_win)
			end
		end, vim.tbl_extend("force", keymap_opts, { buffer = state.layout.title_buf }))
		vim.keymap.set(
			"n",
			"m",
			actions.toggle_preview,
			vim.tbl_extend("force", keymap_opts, { buffer = state.layout.title_buf })
		)
		vim.keymap.set({ "n", "i" }, "<C-j>", function()
			vim.cmd("stopinsert")
			if valid_win(state.layout.desc_win) then
				vim.api.nvim_set_current_win(state.layout.desc_win)
			end
		end, vim.tbl_extend("force", keymap_opts, { buffer = state.layout.title_buf }))
		vim.keymap.set({ "n", "i" }, "<C-k>", function()
			vim.cmd("stopinsert")
		end, vim.tbl_extend("force", keymap_opts, { buffer = state.layout.title_buf }))
	end

	if valid_buf(state.layout.meta_buf) then
		vim.keymap.set(
			"n",
			"q",
			actions.confirm_close,
			vim.tbl_extend("force", keymap_opts, { buffer = state.layout.meta_buf })
		)
		vim.keymap.set(
			"n",
			"<CR>",
			actions.show_assignee_picker,
			vim.tbl_extend("force", keymap_opts, { buffer = state.layout.meta_buf })
		)
		vim.keymap.set("n", "<Tab>", function()
			if valid_win(state.layout.desc_win) then
				vim.api.nvim_set_current_win(state.layout.desc_win)
			end
		end, vim.tbl_extend("force", keymap_opts, { buffer = state.layout.meta_buf }))
		vim.keymap.set("n", "<S-Tab>", function()
			if valid_win(state.layout.title_win) then
				vim.api.nvim_set_current_win(state.layout.title_win)
			end
		end, vim.tbl_extend("force", keymap_opts, { buffer = state.layout.meta_buf }))
		vim.keymap.set(
			"n",
			"m",
			actions.toggle_preview,
			vim.tbl_extend("force", keymap_opts, { buffer = state.layout.meta_buf })
		)
	end

	if valid_buf(state.layout.desc_buf) then
		vim.keymap.set(
			"n",
			"q",
			actions.confirm_close,
			vim.tbl_extend("force", keymap_opts, { buffer = state.layout.desc_buf })
		)
		vim.keymap.set("n", "<Tab>", function()
			if valid_win(state.layout.title_win) then
				vim.api.nvim_set_current_win(state.layout.title_win)
			end
		end, vim.tbl_extend("force", keymap_opts, { buffer = state.layout.desc_buf }))
		vim.keymap.set("n", "<S-Tab>", function()
			if valid_win(state.layout.title_win) then
				vim.api.nvim_set_current_win(state.layout.title_win)
			end
		end, vim.tbl_extend("force", keymap_opts, { buffer = state.layout.desc_buf }))
		vim.keymap.set(
			"n",
			"ga",
			actions.show_assignee_picker,
			vim.tbl_extend("force", keymap_opts, { buffer = state.layout.desc_buf })
		)
		vim.keymap.set(
			"n",
			"gr",
			actions.show_reporter_picker,
			vim.tbl_extend("force", keymap_opts, { buffer = state.layout.desc_buf })
		)
		vim.keymap.set(
			"n",
			"gt",
			actions.show_issue_type_picker,
			vim.tbl_extend("force", keymap_opts, { buffer = state.layout.desc_buf })
		)
		vim.keymap.set(
			"n",
			"m",
			actions.toggle_preview,
			vim.tbl_extend("force", keymap_opts, { buffer = state.layout.desc_buf })
		)
		vim.keymap.set({ "n", "i" }, "<C-k>", function()
			vim.cmd("stopinsert")
			if valid_win(state.layout.title_win) then
				vim.api.nvim_set_current_win(state.layout.title_win)
			end
		end, vim.tbl_extend("force", keymap_opts, { buffer = state.layout.desc_buf }))

		vim.keymap.set({ "n", "i" }, "<C-j>", function()
			vim.cmd("stopinsert")
		end, vim.tbl_extend("force", keymap_opts, { buffer = state.layout.desc_buf }))
	end
end

---@param state IssueState
---@param actions { create_issue: fun(), confirm_close: fun() }
function M.setup_autocmds(state, actions)
	local write_bufs = { state.layout.title_buf, state.layout.desc_buf }
	for _, buf in ipairs(write_bufs) do
		if valid_buf(buf) then
			vim.api.nvim_create_autocmd("BufWriteCmd", {
				buffer = buf,
				callback = function()
					actions.create_issue()
				end,
			})
		end
	end

	local all_bufs =
		{ state.layout.title_buf, state.layout.meta_buf, state.layout.desc_buf, state.layout.container_buf }
	for _, buf in ipairs(all_bufs) do
		if valid_buf(buf) then
			vim.api.nvim_create_autocmd("QuitPre", {
				buffer = buf,
				callback = function()
					vim.schedule(function()
						actions.confirm_close()
					end)
					return true
				end,
			})
		end
	end
end

---@param state IssueState
---@param actions {
--- confirm_close: fun(),
--- toggle_preview: fun(),
--- show_assignee_picker: fun(),
--- show_reporter_picker: fun(),
--- show_issue_type_picker: fun(),
--- create_issue: fun()
---}
function M.setup(state, actions)
	M.setup_keymaps(state, actions)
	M.setup_autocmds(state, {
		create_issue = actions.create_issue,
		confirm_close = actions.confirm_close,
	})
end

return M
