local M = {}
local state = require("atlas.ui.panel.state")

---@param provider "bitbucket"|"jira"
function M.render(provider)
	if provider == "jira" then
		require("atlas.jira.panel.init").refresh()
		return
	end

	if provider == "bitbucket" then
		local item = state.selected_item
		if type(item) == "table" and item.kind == "repo" then
			require("atlas.bitbucket.ui.panel.repository.controller").refresh()
		else
			require("atlas.bitbucket.ui.panel.prs.controller").refresh()
		end
		return
	end
end

return M
