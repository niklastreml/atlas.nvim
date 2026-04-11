local M = {}

local layout = require("atlas.ui.layout")
local keymaps = require("atlas.ui.panel.keymaps")
local state = require("atlas.ui.panel.state")
local ui_state = require("atlas.ui.main.state")

---@param provider "bitbucket"|"jira"|nil
local function deactivate_provider(provider)
	if provider == "jira" then
		require("atlas.jira.panel.init").deactivate()
		return
	end

	if provider == "bitbucket" then
		require("atlas.bitbucket.panel.init").deactivate()
	end
end


function M.open()
	if M.is_open() then
		return
	end

	layout.toggle_detail()
	state.open = M.is_open()

	if state.open then
		local buf = layout.buf_id("detail")
		if buf ~= nil and vim.api.nvim_buf_is_valid(buf) then
			keymaps.register(buf)
		end
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

	local buf = layout.buf_id("detail")
	if buf ~= nil and vim.api.nvim_buf_is_valid(buf) then
		keymaps.remove(buf)
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
	local previous_provider = state.active_provider
	if previous_provider ~= provider then
		deactivate_provider(previous_provider)
	end

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
		local bb_panel = require("atlas.bitbucket.panel.init")

		-- Determine panel type from item kind
		local panel_type = nil
		local panel_item = nil

		if type(item) == "table" then
			if item.kind == "repo" then
				panel_type = "repo"
				panel_item = item
			elseif item.kind == "pr" or item.kind == "pr_meta" then
				panel_type = "pr"
				panel_item = item.pr
			end
		end

		if panel_type ~= nil then
			bb_panel.on_select(panel_type, panel_item)
		else
			bb_panel.on_select(nil, nil)
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
