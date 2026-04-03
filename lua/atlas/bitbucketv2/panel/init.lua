local M = {}

local panel_state = require("atlas.bitbucketv2.panel.state")
local layout = require("atlas.ui.layout")
local footer = require("atlas.ui.components.footer")
local ns = vim.api.nvim_create_namespace("atlas.bitbucketv2.panel")
local mapped_buf = nil

--- Sync render-markdown plugin for the detail buffer (if installed)
--- FIX: Does not work great...
local function sync_render_markdown()
	local buf = layout.buf_id("detail")
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	local ok, render_markdown = pcall(require, "render-markdown")
	if not ok or type(render_markdown.set_buf) ~= "function" then
		return
	end

	pcall(vim.api.nvim_buf_call, buf, function()
		render_markdown.set_buf(true)
	end)

	--FIX: Re-apply tab navigation keys after render-markdown attaches. This is bad and should be refactored
	vim.keymap.set("n", "[", function()
		M.prev_tab()
	end, { buffer = buf, silent = true, nowait = true })

	vim.keymap.set("n", "]", function()
		M.next_tab()
	end, { buffer = buf, silent = true, nowait = true })

	vim.keymap.set("n", "<S-Tab>", function()
		M.prev_tab()
	end, { buffer = buf, silent = true, nowait = true })

	vim.keymap.set("n", "<Tab>", function()
		M.next_tab()
	end, { buffer = buf, silent = true, nowait = true })
end

-- Tab registries for each panel type
local PR_TABS = {
	{ key = "overview", label = "Overview", mod = "atlas.bitbucketv2.panel.tabs.pr.overview" },
	{ key = "activity", label = "Activity", mod = "atlas.bitbucketv2.panel.tabs.pr.activity" },
	{ key = "comments", label = "Comments", mod = "atlas.bitbucketv2.panel.tabs.pr.comments" },
	{ key = "commits", label = "Commits", mod = "atlas.bitbucketv2.panel.tabs.pr.commits" },
	{ key = "files", label = "Files", mod = "atlas.bitbucketv2.panel.tabs.pr.files" },
}

local REPO_TABS = {
	{ key = "overview", label = "Overview", mod = "atlas.bitbucketv2.panel.tabs.repo.overview" },
	{ key = "branches", label = "Branches", mod = "atlas.bitbucketv2.panel.tabs.repo.branches" },
	{ key = "tags", label = "Tags", mod = "atlas.bitbucketv2.panel.tabs.repo.tags" },
}

---@return table[] tabs
local function get_tabs()
	if panel_state.panel_type == "pr" then
		return PR_TABS
	elseif panel_state.panel_type == "repo" then
		return REPO_TABS
	end
	return {}
end

---@param tab_key string
---@return table|nil
local function get_tab_module(tab_key)
	local tabs = get_tabs()
	for _, tab in ipairs(tabs) do
		if tab.key == tab_key then
			local ok, mod = pcall(require, tab.mod)
			if ok then
				return mod
			end
			return nil
		end
	end
	return nil
end

local function register_panel_keys()
	local buf = layout.buf_id("detail")
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	if mapped_buf == buf then
		return
	end

	vim.keymap.set("n", "j", function()
		local tab = get_tab_module(panel_state.current_tab)
		if tab ~= nil and type(tab.move_cursor) == "function" then
			tab.move_cursor(1)
		end
	end, {
		buffer = buf,
		silent = true,
		nowait = true,
		desc = "Next item in tab",
	})

	vim.keymap.set("n", "k", function()
		local tab = get_tab_module(panel_state.current_tab)
		if tab ~= nil and type(tab.move_cursor) == "function" then
			tab.move_cursor(-1)
		end
	end, {
		buffer = buf,
		silent = true,
		nowait = true,
		desc = "Previous item in tab",
	})

	vim.keymap.set("n", "gg", function()
		local tab = get_tab_module(panel_state.current_tab)
		if tab ~= nil and type(tab.move_cursor) == "function" then
			tab.move_cursor(0)
		end
	end, {
		buffer = buf,
		silent = true,
		nowait = true,
		desc = "First item in tab",
	})

	vim.keymap.set("n", "G", function()
		local tab = get_tab_module(panel_state.current_tab)
		if tab ~= nil and type(tab.move_cursor) == "function" then
			tab.move_cursor(math.huge)
		end
	end, {
		buffer = buf,
		silent = true,
		nowait = true,
		desc = "Last item in tab",
	})

	vim.keymap.set("n", "A", function()
		local item = panel_state.current_item
		if type(item) ~= "table" then
			footer.notify("warn", "No item selected")
			return
		end

		-- TODO: Wire actions when UI layer is created
		footer.notify("info", "Actions not yet wired", 1200)
	end, {
		buffer = buf,
		silent = true,
		nowait = true,
		desc = "Open context actions",
	})

	mapped_buf = buf
end

---@param panel_type "pr"|"repo"
---@param item BitbucketPR|BitbucketRepository|nil
function M.on_select(panel_type, item)
	panel_state.set_panel_type(panel_type)
	panel_state.set_current_item(item)
	register_panel_keys()

	if item ~= nil then
		M.select_tab("overview")
	else
		M.render()
	end
end

---@param tab_key string
function M.select_tab(tab_key)
	register_panel_keys()

	local old_tab = get_tab_module(panel_state.current_tab)
	if old_tab and type(old_tab.deactivate) == "function" then
		old_tab.deactivate()
	end

	panel_state.set_current_tab(tab_key)

	local new_tab = get_tab_module(tab_key)
	if new_tab and type(new_tab.activate) == "function" then
		new_tab.activate(panel_state.current_item)
	end

	M.render()
end

function M.next_tab()
	local tabs = get_tabs()
	if #tabs == 0 then
		return
	end

	local idx = 1
	for i, tab in ipairs(tabs) do
		if tab.key == panel_state.current_tab then
			idx = i
			break
		end
	end

	local next_idx = idx + 1
	if next_idx > #tabs then
		next_idx = 1
	end

	M.select_tab(tabs[next_idx].key)
end

function M.prev_tab()
	local tabs = get_tabs()
	if #tabs == 0 then
		return
	end

	local idx = 1
	for i, tab in ipairs(tabs) do
		if tab.key == panel_state.current_tab then
			idx = i
			break
		end
	end

	local prev_idx = idx - 1
	if prev_idx < 1 then
		prev_idx = #tabs
	end

	M.select_tab(tabs[prev_idx].key)
end

function M.render()
	local buf = layout.buf_id("detail")
	local win = layout.win_id("detail")
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	if win == nil or not vim.api.nvim_win_is_valid(win) then
		return
	end

	local lines = {}
	local spans = {}

	if panel_state.current_item == nil then
		lines = { "", "  Nothing selected..." }
		panel_state.line_map = {}
	else
		local tab = get_tab_module(panel_state.current_tab)
		if tab and type(tab.render) == "function" then
			local tab_line_map = nil
			lines, spans, tab_line_map = tab.render(vim.api.nvim_win_get_width(win))
			panel_state.line_map = tab_line_map or {}
		else
			lines = {
				"",
				"  Unknown tab: " .. tostring(panel_state.current_tab) .. ". You shouldn't even be here..󱃞 ",
			}
			panel_state.line_map = {}
		end
	end

	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	for _, span in ipairs(spans or {}) do
		if type(span) == "table" and span.line ~= nil and span.line_hl_group ~= nil then
			vim.api.nvim_buf_set_extmark(buf, ns, span.line, 0, {
				line_hl_group = span.line_hl_group,
			})
		elseif
			type(span) == "table"
			and span.line ~= nil
			and span.start_col ~= nil
			and span.end_col ~= nil
			and span.hl_group ~= nil
		then
			vim.api.nvim_buf_set_extmark(buf, ns, span.line, span.start_col, {
				end_row = span.line,
				end_col = span.end_col,
				hl_group = span.hl_group,
			})
		end
	end
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
	sync_render_markdown()
end

function M.refresh()
	M.render()
end

function M.deactivate()
	local tab = get_tab_module(panel_state.current_tab)
	if tab ~= nil and type(tab.deactivate) == "function" then
		tab.deactivate()
	end
end

---@return table[] tabs
function M.get_available_tabs()
	return get_tabs()
end

---@return string
function M.get_current_tab()
	return panel_state.current_tab
end

---@return "pr"|"repo"|nil
function M.get_panel_type()
	return panel_state.panel_type
end

return M
