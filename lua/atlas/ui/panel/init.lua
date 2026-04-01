local M = {}

local layout = require("atlas.ui.layout")
local state = require("atlas.ui.panel.state")
local ui_state = require("atlas.ui.main.state")

local function current_panel_controller()
	local provider = state.active_provider
	if provider == "jira" then
		return require("atlas.jira.panel.init")
	end

	local item = state.selected_item
	if type(item) == "table" and item.kind == "repo" then
		return require("atlas.bitbucket.ui.panel.repository.controller")
	end
	return require("atlas.bitbucket.ui.panel.prs.controller")
end

local function refresh_current_panel()
	local provider = state.active_provider
	if provider == "jira" then
		require("atlas.jira.panel.init").refresh()
		return
	end

	local item = state.selected_item
	if type(item) == "table" and item.kind == "repo" then
		require("atlas.bitbucket.ui.panel.repository.controller").refresh_selected_repo()
		return
	end
	require("atlas.bitbucket.ui.panel.prs.controller").refresh_selected_pr()
end

local function register_panel_keys()
	local buf = layout.buf_id("detail")
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	vim.keymap.set("n", "q", function()
		M.close()
	end, { buffer = buf, silent = true, nowait = true })

	vim.keymap.set("n", "[", function()
		current_panel_controller().prev_tab()
	end, { buffer = buf, silent = true, nowait = true })

	vim.keymap.set("n", "]", function()
		current_panel_controller().next_tab()
	end, { buffer = buf, silent = true, nowait = true })

	vim.keymap.set("n", "r", function()
		refresh_current_panel()
	end, { buffer = buf, silent = true, nowait = true })
end

function M.open()
	if M.is_open() then
		return
	end

	layout.toggle_detail()
	state.open = M.is_open()

	if state.open then
		register_panel_keys()
	end
end

---@param provider "bitbucket"|"jira"
---@param item table|nil
function M.show(provider, item)
	if not M.is_open() then
		M.open()
	end
	M.on_select(provider, item)
end

function M.close()
	if not M.is_open() then
		return
	end

	layout.toggle_detail()
	state.open = false
end

function M.toggle()
	if M.is_open() then
		M.close()
		return
	end
	M.open()
end

function M.is_open()
	return layout.win_id("detail") ~= nil
end

---@param provider "bitbucket"|"jira"
---@param item table|nil
function M.on_select(provider, item)
	state.set_selection(provider, item)
	if not M.is_open() then
		return
	end

	if provider == "jira" then
		local jira_issue = item
		if type(item) == "table" and type(item._issue) == "table" then
			jira_issue = item._issue
		end
		require("atlas.jira.panel.init").on_select(jira_issue)
		return
	end

	if provider == "bitbucket" then
		local repo_controller = require("atlas.bitbucket.ui.panel.repository.controller")
		local prs_controller = require("atlas.bitbucket.ui.panel.prs.controller")
		repo_controller.on_select(nil)
		prs_controller.on_select(nil)

		if type(item) == "table" and item.kind == "repo" then
			repo_controller.on_select(item)
		else
			prs_controller.on_select(item)
		end
		return
	end

	require("atlas.ui.panel.renderer").render(provider)
end

function M.refresh()
	if not M.is_open() then
		return
	end
	require("atlas.ui.panel.renderer").render(state.active_provider or ui_state.current_view)
end

return M
