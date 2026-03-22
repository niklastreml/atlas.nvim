local M = {}

local table_renderer = require("atlas.ui.components.table")

local help_buf = nil
local help_win = nil
local ns = vim.api.nvim_create_namespace("atlas.help")
local resize_group = vim.api.nvim_create_augroup("AtlasHelpResize", { clear = true })

---@type table<string, { index: number, items: { key: string, desc: string, callback: function|nil }[] }>
local registry = {
	["Commands"] = {
		index = 999,
		items = {},
	},
}

---@type table<integer, table<string, true>>
local bound_keys_by_buf = {}

---@return integer|nil
local function current_atlas_buf()
	local ui_state = require("atlas.ui.state")
	local buf = ui_state.buf_id
	if buf ~= nil and vim.api.nvim_buf_is_valid(buf) then
		return buf
	end
	return nil
end

---@param buf integer
---@param key string
---@param callback function
local function bind_key(buf, key, callback)
	vim.keymap.set("n", key, callback, { buffer = buf, silent = true, nowait = true })
	bound_keys_by_buf[buf] = bound_keys_by_buf[buf] or {}
	bound_keys_by_buf[buf][key] = true
end

---@param buf integer
---@param key string
local function unbind_key(buf, key)
	pcall(vim.keymap.del, "n", key, { buffer = buf })
	if bound_keys_by_buf[buf] ~= nil then
		bound_keys_by_buf[buf][key] = nil
		if next(bound_keys_by_buf[buf]) == nil then
			bound_keys_by_buf[buf] = nil
		end
	end
end

---@param section string
---@param items { key: string, desc: string, callback?: function }[]
---@param opts { index?: number }|nil
function M.register_keys(section, items, opts)
	opts = opts or {}

	if registry[section] == nil then
		registry[section] = {
			index = opts.index or 500, --FIX: Take the last index of the registry and add 1 to it (exclude Commands)
			items = {},
		}
	end

	if opts.index ~= nil then
		registry[section].index = opts.index
	end

	for _, item in ipairs(items or {}) do
		table.insert(registry[section].items, {
			key = item.key,
			desc = item.desc,
			callback = item.callback,
		})

		if item.callback ~= nil and item.key ~= nil and item.key ~= "" then
			local buf = current_atlas_buf()
			if buf ~= nil then
				bind_key(buf, item.key, item.callback)
			end
		end
	end
end

---@param section string
---@param key string
function M.unregister_key(section, key)
	if registry[section] ~= nil then
		local filtered = {}
		for _, item in ipairs(registry[section].items or {}) do
			if item.key ~= key then
				table.insert(filtered, item)
			end
		end
		registry[section].items = filtered
	end

	for buf, _ in pairs(bound_keys_by_buf) do
		if vim.api.nvim_buf_is_valid(buf) then
			unbind_key(buf, key)
		else
			bound_keys_by_buf[buf] = nil
		end
	end
end

function M.clear_keybindings()
	for buf, keys in pairs(bound_keys_by_buf) do
		if vim.api.nvim_buf_is_valid(buf) then
			for key, _ in pairs(keys) do
				pcall(vim.keymap.del, "n", key, { buffer = buf })
			end
		end
		bound_keys_by_buf[buf] = nil
	end
end

local function build_rows()
	local rows = {}
	local sections = {}

	for section, entry in pairs(registry) do
		table.insert(sections, {
			name = section,
			index = entry.index or 500,
		})
	end

	table.sort(sections, function(a, b)
		return a.index < b.index
	end)

	for _, section in ipairs(sections) do
		local items = registry[section.name].items or {}
		if #items > 0 or section.name == "Commands" then
			table.insert(rows, {
				kind = "section",
				key = section.name .. ":",
				desc = "",
			})

			for _, item in ipairs(items) do
				table.insert(rows, {
					kind = "shortcut",
					key = item.key,
					desc = item.desc,
				})
			end

			table.insert(rows, {
				kind = "spacer",
				key = "",
				desc = "",
				separator = true,
			})
		end
	end
	return rows
end

local function popup_size(lines)
	local width = math.floor(vim.o.columns * 0.4)
	local height = math.min(#lines, math.floor(vim.o.lines * 0.8))
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	return {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " Help ",
		title_pos = "center",
		zindex = 260,
	}
end

local function ensure_buffer()
	if help_buf ~= nil and vim.api.nvim_buf_is_valid(help_buf) then
		return help_buf
	end

	help_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = help_buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = help_buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = help_buf })
	vim.api.nvim_set_option_value("modifiable", false, { buf = help_buf })
	vim.api.nvim_set_option_value("filetype", "atlas", { buf = help_buf })
	vim.api.nvim_set_option_value("syntax", "OFF", { buf = help_buf })
	pcall(vim.treesitter.stop, help_buf)

	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = help_buf,
		once = true,
		callback = function()
			help_buf = nil
			help_win = nil
		end,
	})

	return help_buf
end

local function apply_window_style(win)
	vim.api.nvim_set_option_value(
		"winhighlight",
		"Normal:NormalFloat,NormalNC:NormalFloat,EndOfBuffer:NormalFloat,FloatBorder:FloatBorder",
		{ win = win }
	)
	vim.api.nvim_set_option_value("wrap", false, { win = win })
	vim.api.nvim_set_option_value("cursorline", false, { win = win })
end

local function apply_spans(buf, spans)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	for _, span in ipairs(spans or {}) do
		vim.api.nvim_buf_set_extmark(buf, ns, span.line, span.start_col, {
			end_row = span.line,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end
end

function M.close()
	if help_win ~= nil and vim.api.nvim_win_is_valid(help_win) then
		vim.api.nvim_win_close(help_win, true)
	end
	help_win = nil
end

local function recenter_if_open()
	if help_win == nil or not vim.api.nvim_win_is_valid(help_win) then
		return
	end
	if help_buf == nil or not vim.api.nvim_buf_is_valid(help_buf) then
		return
	end

	local lines = vim.api.nvim_buf_get_lines(help_buf, 0, -1, false)
	vim.api.nvim_win_set_config(help_win, popup_size(lines))
end

function M.open()
	if help_win ~= nil and vim.api.nvim_win_is_valid(help_win) then
		M.close()
		return
	end

	local rows = build_rows()
	local lines, _, spans = table_renderer.render({
		width = math.min(math.floor(vim.o.columns * 0.4), 100),
		margin = 1,
		fill = false,
		columns = {
			{ key = "key", name = "Key", min_width = 18, can_grow = false, header_hl = "Normal" },
			{ key = "desc", name = "Description", min_width = 42, header_hl = "Normal" },
		},
		rows = rows,
	})

	local buf = ensure_buffer()
	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
	apply_spans(buf, spans)

	help_win = vim.api.nvim_open_win(buf, true, popup_size(lines))
	apply_window_style(help_win)

	local opts = { buffer = buf, silent = true, nowait = true }
	vim.keymap.set("n", "q", M.close, opts)
	vim.keymap.set("n", "<Esc>", M.close, opts)
	vim.keymap.set("n", "?", M.close, opts)
end

function M.toggle()
	if help_win ~= nil and vim.api.nvim_win_is_valid(help_win) then
		M.close()
		return
	end
	M.open()
end

vim.api.nvim_create_autocmd("VimResized", {
	group = resize_group,
	callback = recenter_if_open,
})

return M
