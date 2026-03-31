local M = {}
local logger = require("atlas.core.logger")

---@param opts AtlasConfig|nil
function M.setup(opts)
	require("atlas.config").setup(opts)
	require("atlas.core.logger").clear()
end

local function bootstrap_common()
	require("atlas.ui.highlights").setup()
	require("atlas.ui.components.footer").setup()

	require("atlas.ui.popups.help").register_keys("Commands", {
		{ key = ":AtlasBitbucket", desc = "Open Bitbucket picker" },
		{ key = ":AtlasJira", desc = "Open Jira picker" },
	}, { index = 999 })
end

---@param view "jira"|"bitbucket"
local function bootstrap_provider(view)
	if view == "bitbucket" then
		require("atlas.bitbucket").setup()
		return
	end

	require("atlas.jira").setup()
end

function M.open(view)
	logger.loginfo("Atlas open requested", { view = view })

	local layout = require("atlas.ui.layout")
	layout.ensure_open()
	bootstrap_common()
	bootstrap_provider(view)
	layout.open(view)

	--FIX: This removes the statusline but is there a better way to do this? Could also effect other plugins that rely on the statusline
	vim.o.laststatus = 0
	vim.schedule(function()
		vim.o.laststatus = 0
	end)
end

return M
