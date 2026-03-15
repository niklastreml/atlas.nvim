local M = {}

local state = require("atlas.ui.state")
local resize_id = nil

local function render_current_view()
	if state.current_view == "jira" then
		require("atlas.jira").setup()
	end
end

local function setup_resize_handler()
	if resize_id ~= nil then
		vim.api.nvim_del_autocmd(resize_id)
	end

	local resize_group = vim.api.nvim_create_augroup("AtlasUIResize", { clear = true })
	resize_id = vim.api.nvim_create_autocmd("VimResized", {
		group = resize_group,
		callback = function()
			local window = require("atlas.ui.window")
			if not window.is_open() then
				return
			end

			window.resize()
			render_current_view()
		end,
	})
end

function M.render()
	local window = require("atlas.ui.window")
	if not window.is_open() then
		window.open()
	end

	setup_resize_handler()
	render_current_view()
end

return M
