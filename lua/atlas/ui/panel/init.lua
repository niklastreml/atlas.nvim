local M = {}

local layout = require("atlas.ui.layout")
local keymaps = require("atlas.ui.panel.keymaps")
local state = require("atlas.ui.panel.state")
local ui_state = require("atlas.ui.state")

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

---@param selection AtlasPanelSelection
function M.show(selection)
	if not M.is_open() then
		M.open()
	end
	M.on_select(selection)
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

---@param selection AtlasPanelSelection|nil
---@param opts? { force_refresh?: boolean }
function M.on_select(selection, opts)
	opts = opts or {}
	if selection == nil then
		return
	end

	local provider = selection.provider
	local previous_provider = state.active_provider
	if previous_provider ~= provider then
		deactivate_provider(previous_provider)
	end

	if provider == "jira" then
		---@cast selection AtlasJiraPanelSelection
		state.set_selection(selection)
		if not M.is_open() then
			return
		end

		require("atlas.jira.panel.init").on_select(selection.item, { force_refresh = opts.force_refresh == true })
		return
	end

	if provider == "bitbucket" then
		---@cast selection AtlasBitbucketPanelSelection
		local bb_panel = require("atlas.bitbucket.panel.init")
		state.set_selection(selection)
		if not M.is_open() then
			return
		end

		bb_panel.on_select(selection.panel_type, selection.item, { force_refresh = opts.force_refresh == true })
	end
end

function M.refresh()
	if not M.is_open() then
		return
	end
	require("atlas.ui.panel.renderer").render(state.active_provider or ui_state.current_view)
end

return M
