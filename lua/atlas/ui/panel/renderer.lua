local M = {}
local state = require("atlas.ui.panel.state")

---@param provider "bitbucket"|"jira"
function M.render(provider)
	if provider == "jira" then
		require("atlas.jira.panel.init").refresh()
		return
	end

	if provider == "bitbucket" then
		require("atlas.bitbucketv2.panel.init").refresh()
		return
	end
end

return M
