local M = {}

local panel_state = require("atlas.bitbucket.panel.state")
local keymaps = require("atlas.bitbucket.panel.keymaps")
local layout = require("atlas.ui.layout")

---@class BitbucketPanelTabsEntry
---@field render fun(width: integer): string[], table[], table|nil
---@field is_loading fun(): boolean
---@field set_item fun(item: BitbucketPR|BitbucketRepository|nil)
---@field move fun(delta: integer)
---@field refresh fun()
---@field next_tab fun()
---@field prev_tab fun()
---@field deactivate fun()

local ns = vim.api.nvim_create_namespace("atlas.bitbucket.panel")
local render_timer = nil
local RENDER_INTERVAL_MS = 120

---@param panel_type "pr"|"repo"|nil
---@return BitbucketPanelTabsEntry|nil
local function tab_entry(panel_type)
	if panel_type == "pr" then
		---@type BitbucketPanelTabsEntry
		return require("atlas.bitbucket.panel.tabs.pr")
	elseif panel_type == "repo" then
		---@type BitbucketPanelTabsEntry
		return require("atlas.bitbucket.panel.tabs.repo")
	end

	return nil
end

local function stop_render_loop()
	if render_timer ~= nil then
		render_timer:stop()
		render_timer:close()
		render_timer = nil
	end
end

local function active_panel_loading()
	local entry = tab_entry(panel_state.panel_type)
	return entry ~= nil and entry.is_loading() == true
end

local function sync_render_loop()
	if not active_panel_loading() then
		stop_render_loop()
		return
	end

	if render_timer ~= nil then
		return
	end

	render_timer = vim.loop.new_timer()
	if render_timer == nil then
		return
	end

	render_timer:start(
		0,
		RENDER_INTERVAL_MS,
		vim.schedule_wrap(function()
			if not active_panel_loading() then
				stop_render_loop()
				return
			end

			M.render()
		end)
	)
end

---@param panel_type "pr"|"repo"
---@param item BitbucketPR|BitbucketRepository|nil
function M.on_select(panel_type, item)
	local previous_panel_type = panel_state.panel_type

	if previous_panel_type ~= panel_type then
		local previous_entry = tab_entry(previous_panel_type)
		if previous_entry ~= nil then
			previous_entry.deactivate()
		end
	end

	panel_state.set_panel_type(panel_type)
	panel_state.set_current_item(item)
	local buf = layout.buf_id("detail")
	if buf ~= nil then
		keymaps.register(buf, {
			move = M.move,
			refresh_tab = M.refresh_tab,
			refresh = M.refresh,
		})
	end

	local entry = tab_entry(panel_type)
	if entry ~= nil and item ~= nil then
		entry.set_item(item)
	end

	M.render()
end

function M.next_tab()
	local entry = tab_entry(panel_state.panel_type)
	if entry == nil then
		return
	end
	entry.next_tab()
	M.render()
end

function M.prev_tab()
	local entry = tab_entry(panel_state.panel_type)
	if entry == nil then
		return
	end
	entry.prev_tab()
	M.render()
end

---@param delta integer
function M.move(delta)
	local entry = tab_entry(panel_state.panel_type)
	if entry == nil then
		return
	end
	entry.move(delta)
end

function M.refresh_tab()
	local entry = tab_entry(panel_state.panel_type)
	if entry == nil then
		return
	end
	entry.refresh()
end

function M.render()
	local buf = layout.buf_id("detail")
	local win = layout.win_id("detail")
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		stop_render_loop()
		return
	end
	if win == nil or not vim.api.nvim_win_is_valid(win) then
		stop_render_loop()
		return
	end

	local lines = {}
	local spans = {}

	if panel_state.current_item == nil then
		lines = { "", "  Nothing selected..." }
		panel_state.line_map = {}
	else
		local entry = tab_entry(panel_state.panel_type)
		if entry ~= nil then
			local tab_line_map = nil
			lines, spans, tab_line_map = entry.render(vim.api.nvim_win_get_width(win))
			panel_state.line_map = tab_line_map or {}
		else
			lines = {
				"",
				"  Unknown tab state. You shouldn't even be here..󱃞 ",
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
	sync_render_loop()
end

function M.refresh()
	M.render()
end

function M.deactivate()
	stop_render_loop()
	local entry = tab_entry(panel_state.panel_type)
	if entry ~= nil then
		entry.deactivate()
	end
end

return M
