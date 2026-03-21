local M = {}

local state = require("atlas.ui.state")
local resize_id = nil

local function render_current_view(opts)
	if opts == "jira" then
		state.current_view = "jira"
		require("atlas.jira").setup()
	elseif opts == "bitbucket" then
		state.current_view = "bitbucket"
		require("atlas.bitbucket").setup()
	elseif opts == "github" then
		state.current_view = "github"
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
			render_current_view(state.current_view)
		end,
	})
end

---@param opts { view: "jira"|"bitbucket"|"github"}
function M.render(opts)
	local window = require("atlas.ui.window")
	if not window.is_open() then
		window.open()
	end

	setup_resize_handler()

	if opts == "jira" then
		state.current_view = "jira"
	elseif opts == "bitbucket" then
		state.current_view = "bitbucket"
	elseif opts == "github" then
		state.current_view = "github"
	end

	render_current_view(opts)
end

return M
