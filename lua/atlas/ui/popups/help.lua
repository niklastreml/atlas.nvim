---FIX: Pretty ugly view but it works for now. Please make it nicer looking..
local M = {}

local table_renderer = require("atlas.ui.components.table_tree")

local ns = vim.api.nvim_create_namespace("atlas.help")
local resize_group = vim.api.nvim_create_augroup("AtlasHelp2Resize", { clear = true })

local help_buf = nil
local help_win = nil
local active_source_buf = nil

---@type table<integer, { sections: table<string, { index: number, items: { key: string, desc: string, callback: function|nil }[] }>, bound_keys: table<string, function|true>, autocmd_id: integer|nil }>
local registry_by_buf = {}

---@param buf integer
---@return boolean
local function valid_buf(buf)
	return type(buf) == "number" and vim.api.nvim_buf_is_valid(buf)
end

---@return integer
local function current_target_buf()
	local layout = require("atlas.ui.layout")
	local buf = layout.buf_id("main")
	if valid_buf(buf) then
		return buf
	end
	return vim.api.nvim_get_current_buf()
end

---@param buf integer
---@return table
local function ensure_buffer_registry(buf)
	if registry_by_buf[buf] == nil then
		registry_by_buf[buf] = {
			sections = {},
			bound_keys = {},
			autocmd_id = nil,
		}
	end

	registry_by_buf[buf].sections = registry_by_buf[buf].sections or {}
	registry_by_buf[buf].bound_keys = registry_by_buf[buf].bound_keys or {}

	if registry_by_buf[buf].autocmd_id == nil then
		registry_by_buf[buf].autocmd_id = vim.api.nvim_create_autocmd("BufWipeout", {
			buffer = buf,
			once = true,
			callback = function()
				registry_by_buf[buf] = nil
				if active_source_buf == buf then
					active_source_buf = nil
					if help_win ~= nil and vim.api.nvim_win_is_valid(help_win) then
						vim.api.nvim_win_close(help_win, true)
					end
					help_win = nil
				end
			end,
		})
	end

	return registry_by_buf[buf]
end

---@param section table
---@param key string
---@return boolean
local function has_item(section, key)
	for _, item in ipairs(section.items) do
		if item.key == key then
			return true
		end
	end
	return false
end

---@param buf integer
---@param key string
---@param callback function
local function bind_key(buf, key, callback)
	vim.keymap.set("n", key, callback, { buffer = buf, silent = true, nowait = true })
	registry_by_buf[buf].bound_keys[key] = callback
end

---@param buf integer
local function ensure_help_key(buf)
	local entry = ensure_buffer_registry(buf)
	if entry.bound_keys["?"] ~= nil then
		return
	end

	bind_key(buf, "?", function()
		M.toggle(buf)
	end)
end

---@param buf integer
---@return table[]
local function build_rows(buf)
	local rows = {}
	local entry = registry_by_buf[buf]
	if entry == nil then
		return rows
	end

	local sections = {}
	for name, section in pairs(entry.sections) do
		table.insert(sections, {
			name = name,
			index = section.index or 500,
		})
	end

	table.sort(sections, function(a, b)
		return a.index < b.index
	end)

	for _, section in ipairs(sections) do
		local items = entry.sections[section.name].items or {}
		if #items > 0 then
			table.insert(rows, { kind = "section", key = section.name .. ":", desc = "" })
			for _, item in ipairs(items) do
				table.insert(rows, { kind = "shortcut", key = item.key, desc = item.desc })
			end
			table.insert(rows, { kind = "spacer", key = "", desc = "", separator = true })
		end
	end

	return rows
end

---@param lines string[]
---@return table
local function popup_size(lines)
	local width = math.min(math.floor(vim.o.columns * 0.45), 100)
	local height = math.min(#lines, math.floor(vim.o.lines * 0.8))
	return {
		relative = "editor",
		width = width,
		height = math.max(height, 1),
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
		title = " Help ",
		title_pos = "center",
		zindex = 260,
	}
end

---@return integer
local function ensure_help_buffer()
	if help_buf ~= nil and vim.api.nvim_buf_is_valid(help_buf) then
		return help_buf
	end

	help_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = help_buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = help_buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = help_buf })
	vim.api.nvim_set_option_value("modifiable", false, { buf = help_buf })

	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = help_buf,
		once = true,
		callback = function()
			help_buf = nil
			help_win = nil
			active_source_buf = nil
		end,
	})

	return help_buf
end

---@param buf integer
---@param spans table[]
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

local function apply_window_style(win)
	vim.api.nvim_set_option_value(
		"winhighlight",
		"Normal:NormalFloat,NormalNC:NormalFloat,EndOfBuffer:NormalFloat,FloatBorder:FloatBorder",
		{ win = win }
	)
	vim.api.nvim_set_option_value("wrap", false, { win = win })
	vim.api.nvim_set_option_value("cursorline", false, { win = win })
end

function M.close()
	if help_win ~= nil and vim.api.nvim_win_is_valid(help_win) then
		vim.api.nvim_win_close(help_win, true)
	end
	help_win = nil
end

---@param buf integer|nil
function M.open(buf)
	local target_buf = buf or current_target_buf()
	if not valid_buf(target_buf) then
		return
	end

	local rows = build_rows(target_buf)
	local lines, _, spans = table_renderer.render({
		width = math.min(math.floor(vim.o.columns * 0.45), 100),
		margin = 1,
		fill = false,
		columns = {
			{ key = "key", name = "Key", min_width = 18, can_grow = false, header_hl = "Normal" },
			{ key = "desc", name = "Description", min_width = 42, header_hl = "Normal" },
		},
		rows = rows,
	})

	local buf_id = ensure_help_buffer()
	vim.api.nvim_set_option_value("modifiable", true, { buf = buf_id })
	vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf_id })
	apply_spans(buf_id, spans)

	active_source_buf = target_buf

	if help_win ~= nil and vim.api.nvim_win_is_valid(help_win) then
		vim.api.nvim_win_set_config(help_win, popup_size(lines))
		vim.api.nvim_set_current_win(help_win)
	else
		help_win = vim.api.nvim_open_win(buf_id, true, popup_size(lines))
	end

	apply_window_style(help_win)
	local opts = { buffer = buf_id, silent = true, nowait = true }
	vim.keymap.set("n", "q", M.close, opts)
	vim.keymap.set("n", "<Esc>", M.close, opts)
	vim.keymap.set("n", "?", M.close, opts)
end

---@param buf integer|nil
function M.toggle(buf)
	if help_win ~= nil and vim.api.nvim_win_is_valid(help_win) then
		if active_source_buf == (buf or current_target_buf()) then
			M.close()
			return
		end
	end
	M.open(buf)
end

---@param section string
---@param items { key: string, desc: string, callback?: function }[]
---@param opts { index?: number, add_to_registry?: boolean, buf?: integer, bind_help?: boolean }|nil
function M.register_keys(section, items, opts)
	opts = opts or {}
	local target_buf = opts.buf or current_target_buf()
	if not valid_buf(target_buf) then
		return
	end

	local entry = ensure_buffer_registry(target_buf)
	local add_to_registry = opts.add_to_registry ~= false

	if entry.sections[section] == nil then
		entry.sections[section] = {
			index = opts.index or 500,
			items = {},
		}
	elseif opts.index ~= nil then
		entry.sections[section].index = opts.index
	end

	local has_custom_help = false
	for _, item in ipairs(items or {}) do
		if item.key == "?" and item.callback ~= nil then
			has_custom_help = true
		end

		if
			add_to_registry
			and item.key ~= nil
			and item.key ~= ""
			and not has_item(entry.sections[section], item.key)
		then
			table.insert(entry.sections[section].items, {
				key = item.key,
				desc = item.desc,
				callback = item.callback,
			})
		end

		if item.callback ~= nil and item.key ~= nil and item.key ~= "" then
			bind_key(target_buf, item.key, item.callback)
		end
	end

	if opts.bind_help ~= false and not has_custom_help then
		ensure_help_key(target_buf)
		if add_to_registry and not has_item(entry.sections["General"] or { items = {} }, "?") then
			entry.sections["General"] = entry.sections["General"] or { index = 100, items = {} }
			table.insert(entry.sections["General"].items, {
				key = "?",
				desc = "Toggle this help popup",
				callback = nil,
			})
		end
	end
end

---@param section string
---@param key string
---@param opts { buf?: integer }|nil
function M.unregister_key(section, key, opts)
	local target_buf = (opts and opts.buf) or current_target_buf()
	local entry = registry_by_buf[target_buf]
	if entry == nil then
		return
	end

	if entry.sections[section] ~= nil then
		local filtered = {}
		for _, item in ipairs(entry.sections[section].items) do
			if item.key ~= key then
				table.insert(filtered, item)
			end
		end
		entry.sections[section].items = filtered
	end

	pcall(vim.keymap.del, "n", key, { buffer = target_buf })
	entry.bound_keys[key] = nil
end

---@param buf integer|nil
function M.clear_keybindings(buf)
	if buf ~= nil then
		local entry = registry_by_buf[buf]
		if entry == nil then
			return
		end
		for key, _ in pairs(entry.bound_keys) do
			pcall(vim.keymap.del, "n", key, { buffer = buf })
		end
		entry.bound_keys = {}
		return
	end

	for b, entry in pairs(registry_by_buf) do
		if valid_buf(b) then
			for key, _ in pairs(entry.bound_keys) do
				pcall(vim.keymap.del, "n", key, { buffer = b })
			end
		end
		entry.bound_keys = {}
	end
end

vim.api.nvim_create_autocmd("VimResized", {
	group = resize_group,
	callback = function()
		if help_win == nil or not vim.api.nvim_win_is_valid(help_win) then
			return
		end
		if help_buf == nil or not vim.api.nvim_buf_is_valid(help_buf) then
			return
		end

		local lines = vim.api.nvim_buf_get_lines(help_buf, 0, -1, false)
		vim.api.nvim_win_set_config(help_win, popup_size(lines))
	end,
})

return M
