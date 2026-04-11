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

	require("atlas.ui.popups.help").register_command("Commands", {
		{ name = "AtlasBitbucket", desc = "Open Bitbucket picker" },
		{ name = "AtlasJira", desc = "Open Jira picker" },
		{ name = "AtlasJqlSearch", desc = "Start JQL Search" },
		{ name = "AtlasClearCache", desc = "Clear Atlas cache" },
		{ name = "AtlasLogs", desc = "Open Atlas logs" },
	}, { index = 999, buffer = require("atlas.ui.layout").buf_id("main") })
end

---@param view "jira"|"bitbucket"
---@param opts table|nil
local function bootstrap_provider(view, opts)
	if view == "bitbucket" then
		require("atlas.bitbucket").setup()
		return
	end

	require("atlas.jira").setup(opts)
end

---@param view "jira"|"bitbucket"
---@param opts table|nil
function M.open(view, opts)
	logger.loginfo("Atlas open requested", { view = view })

	local layout = require("atlas.ui.layout")
	local panel = require("atlas.ui.panel")
	if panel.is_open() then
		panel.close()
	end

	layout.ensure_open()
	bootstrap_common()
	bootstrap_provider(view, opts)
	layout.open(view)
end

return M
