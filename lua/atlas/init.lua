local M = {}

local bootstrapped = false

M.setup = function(opts)
	require("atlas.config").setup(opts)
end

local function bootstrap()
	if bootstrapped then
		return
	end

	require("atlas.ui.components.footer").setup()
	require("atlas.jira").setup()
	require("atlas.bitbucket").setup()
	require("atlas.github").setup()

	require("atlas.ui.popups.help").register_keys("Commands", {
		{ key = ":AtlasBitbucket", desc = "Open Bitbucket picker" },
		{ key = ":AtlasJira", desc = "Open Jira picker" },
		{ key = ":AtlasGithub", desc = "Open Github picker" },
	}, { index = 999 })

	bootstrapped = true
end

function M.open(view)
	local window = require("atlas.ui.window")
	if not window.is_open() then
		window.open()
	end

	bootstrap()
	require("atlas.ui.renderer").render(view)
end

return M
