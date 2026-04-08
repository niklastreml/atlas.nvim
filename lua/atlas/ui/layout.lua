local M = {}

local footer = require("atlas.ui.components.footer")
local ui_state = require("atlas.ui.main.state")

local state = {
	main_win = nil,
	main_buf = nil,
	tab_id = nil,
	prev_win = nil,
	footer_win = nil,
	footer_buf = nil,
	detail_win = nil,
	detail_buf = nil,
}

local resize_group = vim.api.nvim_create_augroup("AtlasUILayoutResize", { clear = true })

local function valid_win(win)
	return win ~= nil and vim.api.nvim_win_is_valid(win)
end

local function valid_buf(buf)
	return buf ~= nil and vim.api.nvim_buf_is_valid(buf)
end

local function apply_main_win_opts(win)
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
	vim.api.nvim_set_option_value("statusline", "", { win = win })
	vim.api.nvim_set_option_value(
		"winhighlight",
		"Normal:Normal,NormalFloat:Normal,FloatBorder:FloatBorder,CursorLine:CursorLine",
		{ win = win }
	)
end

local function apply_footer_win_opts(win)
	vim.api.nvim_set_option_value("number", false, { win = win })
	vim.api.nvim_set_option_value("relativenumber", false, { win = win })
	vim.api.nvim_set_option_value("signcolumn", "no", { win = win })
	vim.api.nvim_set_option_value("statuscolumn", "", { win = win })
	vim.api.nvim_set_option_value("foldcolumn", "0", { win = win })
	vim.api.nvim_set_option_value("wrap", false, { win = win })
	vim.api.nvim_set_option_value("cursorline", false, { win = win })
	vim.api.nvim_set_option_value("winbar", " ", { win = win })
	vim.api.nvim_set_option_value("statusline", "", { win = win })
	vim.api.nvim_set_option_value("winfixheight", true, { win = win })
end

local function apply_detail_win_opts(win)
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
	vim.api.nvim_set_option_value("statusline", "", { win = win })
	vim.api.nvim_set_option_value("winfixwidth", true, { win = win })
end

local function create_buf(name, filetype)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, name)
	vim.api.nvim_set_option_value("buflisted", false, { buf = buf })
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "hide", { buf = buf })
	vim.api.nvim_set_option_value("filetype", filetype, { buf = buf })
	vim.api.nvim_set_option_value("syntax", "OFF", { buf = buf })
	pcall(vim.treesitter.stop, buf)
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
	return buf
end

local function delete_buf(buf)
	if valid_buf(buf) then
		pcall(vim.api.nvim_buf_delete, buf, { force = true })
	end
end

---@param buf_field "main_buf"|"footer_buf"|"detail_buf"
---@param name string
---@param filetype string
---@return integer
local function ensure_buf(buf_field, name, filetype)
	local existing = state[buf_field]
	if existing and valid_buf(existing) then
		return existing
	end

	local buf = create_buf(name, filetype)
	state[buf_field] = buf
	return buf
end

---@param anchor integer
---@param split_cmd string
---@param buf integer
---@param apply_opts fun(win: integer)
---@return integer
local function create_window(anchor, split_cmd, buf, apply_opts)
	local prev = vim.api.nvim_get_current_win()
	vim.api.nvim_set_current_win(anchor)
	vim.cmd(split_cmd)
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, buf)
	apply_opts(win)
	if valid_win(prev) then
		vim.api.nvim_set_current_win(prev)
	end
	return win
end

local function ensure_main()
	if valid_win(state.main_win) and valid_buf(state.main_buf) then
		return
	end

	state.prev_win = vim.api.nvim_get_current_win()

	local main_buf = ensure_buf("main_buf", "Atlas", "atlas")

	vim.cmd("tabnew")
	state.tab_id = vim.api.nvim_get_current_tabpage()
	state.main_win = vim.api.nvim_get_current_win()

	local tab_buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_win_set_buf(state.main_win, main_buf)
	if tab_buf ~= main_buf and valid_buf(tab_buf) then
		pcall(vim.api.nvim_buf_delete, tab_buf, { force = true })
	end

	apply_main_win_opts(state.main_win)

	local help = require("atlas.ui.popups.help")
	help.register_keys("General", {
		{ key = "q", desc = "Close Atlas window" },
	})
	vim.keymap.set("n", "q", function()
		M.close()
	end, { buffer = main_buf, silent = true, nowait = true })
end

local function ensure_footer()
	if not valid_win(state.main_win) then
		return
	end

	local buf = ensure_buf("footer_buf", "AtlasFooter", "atlas-footer")
	if valid_win(state.footer_win) then
		vim.api.nvim_win_set_buf(state.footer_win, buf)
	else
		state.footer_win = create_window(state.main_win, "botright split", buf, apply_footer_win_opts)
	end

	pcall(vim.api.nvim_win_set_height, state.footer_win, 1)
	local logs_win = require("atlas.ui.logs").win_id()
	if logs_win == nil then
		pcall(function()
			vim.api.nvim_win_call(state.footer_win, function()
				vim.cmd("wincmd J")
			end)
		end)
	else
		pcall(function()
			vim.api.nvim_win_call(logs_win, function()
				vim.cmd("wincmd J")
			end)
		end)
	end
end

function M.is_open()
	return valid_win(state.main_win)
end

---@param pane "main"|"footer"|"detail"
---@return integer|nil
function M.win_id(pane)
	local key = pane .. "_win"
	if valid_win(state[key]) then
		return state[key]
	end
	return nil
end

---@param pane "main"|"footer"|"detail"
---@return integer|nil
function M.buf_id(pane)
	local key = pane .. "_buf"
	if valid_buf(state[key]) then
		return state[key]
	end
	return nil
end

function M.toggle_detail()
	if not valid_win(state.main_win) then
		return
	end

	if valid_win(state.detail_win) then
		vim.api.nvim_win_close(state.detail_win, true)
		state.detail_win = nil
		return
	end

	state.detail_buf = ensure_buf("detail_buf", "AtlasDetail", "")
	state.detail_win = create_window(state.main_win, "rightbelow vsplit", state.detail_buf, apply_detail_win_opts)
	pcall(vim.api.nvim_win_set_width, state.detail_win, math.max(math.floor(vim.o.columns * 0.40), 40))
end

function M.reflow()
	if not M.is_open() then
		return
	end

	ensure_footer()
	if valid_win(state.detail_win) then
		pcall(vim.api.nvim_win_set_width, state.detail_win, math.max(math.floor(vim.o.columns * 0.40), 40))
	end
	footer.refresh()
end

function M.open(view)
	M.ensure_open()
	require("atlas.ui.main.renderer").render(view, { autofocus = true })
	footer.refresh()
end

function M.ensure_open()
	ensure_main()
	ensure_footer()
	require("atlas.ui.navigation").register_keys()
end

function M.close()
	if valid_win(state.detail_win) then
		vim.api.nvim_win_close(state.detail_win, true)
	end
	if valid_win(state.footer_win) then
		vim.api.nvim_win_close(state.footer_win, true)
	end

	state.detail_win = nil
	state.footer_win = nil

	if valid_win(state.main_win) then
		if state.tab_id ~= nil and vim.api.nvim_tabpage_is_valid(state.tab_id) then
			local current_tab = vim.api.nvim_get_current_tabpage()
			if current_tab ~= state.tab_id then
				vim.api.nvim_set_current_tabpage(state.tab_id)
			end
			vim.cmd("tabclose")
		else
			vim.api.nvim_win_close(state.main_win, true)
		end
	end

	delete_buf(state.detail_buf)
	delete_buf(state.footer_buf)
	delete_buf(state.main_buf)

	state.main_win = nil
	state.main_buf = nil
	state.tab_id = nil
	state.detail_buf = nil
	state.footer_buf = nil

	if valid_win(state.prev_win) then
		vim.api.nvim_set_current_win(state.prev_win)
	end
	state.prev_win = nil
end

--- When scrolling in the panel window the main view kinda break and this helps. I dont know why tho..
vim.api.nvim_create_autocmd("WinScrolled", {
	group = resize_group,
	callback = function()
		if not M.is_open() then
			return
		end
		if vim.api.nvim_get_current_tabpage() ~= state.tab_id then
			return
		end
		if state.detail_win ~= nil and vim.v.event[tostring(state.detail_win)] ~= nil then
			vim.cmd("redraw!")
		end
	end,
})

vim.api.nvim_create_autocmd({ "VimResized", "WinResized" }, {
	group = resize_group,
	callback = function()
		if not M.is_open() then
			return
		end
		M.reflow()
		require("atlas.ui.main.renderer").render(ui_state.current_view)
		require("atlas.ui.panel.init").refresh()
	end,
})

return M
