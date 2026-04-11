local M = {}

local panel_state = require("atlas.bitbucket.panel.state")
local keymaps = require("atlas.bitbucket.panel.keymaps")
local layout = require("atlas.ui.layout")
local ns = vim.api.nvim_create_namespace("atlas.bitbucket.panel")

-- Tab registries for each panel type
local PR_TABS = {
	{ key = "overview", label = "Overview", mod = "atlas.bitbucket.panel.tabs.pr.overview" },
	{ key = "activity", label = "Activity", mod = "atlas.bitbucket.panel.tabs.pr.activity" },
	{ key = "comments", label = "Comments", mod = "atlas.bitbucket.panel.tabs.pr.comments" },
	{ key = "commits", label = "Commits", mod = "atlas.bitbucket.panel.tabs.pr.commits" },
	{ key = "files", label = "Files", mod = "atlas.bitbucket.panel.tabs.pr.files" },
}

local REPO_TABS = {
	{ key = "overview", label = "Overview", mod = "atlas.bitbucket.panel.tabs.repo.overview" },
	{ key = "branches", label = "Branches", mod = "atlas.bitbucket.panel.tabs.repo.branches" },
	{ key = "tags", label = "Tags", mod = "atlas.bitbucket.panel.tabs.repo.tags" },
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

---@param panel_type "pr"|"repo"|nil
---@param tab_key string
---@return table|nil
local function get_tab_module_for(panel_type, tab_key)
	local tabs = {}
	if panel_type == "pr" then
		tabs = PR_TABS
	elseif panel_type == "repo" then
		tabs = REPO_TABS
	end

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

---@param panel_type "pr"|"repo"
---@param item BitbucketPR|BitbucketRepository|nil
function M.on_select(panel_type, item)
	local previous_panel_type = panel_state.panel_type
	local previous_tab = panel_state.current_tab

	if previous_panel_type ~= panel_type then
		local previous_tab_mod = get_tab_module_for(previous_panel_type, previous_tab)
		if previous_tab_mod and type(previous_tab_mod.deactivate) == "function" then
			previous_tab_mod.deactivate()
		end
	end

	panel_state.set_panel_type(panel_type)
	panel_state.set_current_item(item)
	local buf = layout.buf_id("detail")
	if buf ~= nil then
		keymaps.register(buf)
	end

	if item ~= nil then
		M.select_tab("overview")
	else
		M.render()
	end
end

---@param tab_key string
function M.select_tab(tab_key)
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
