local M = {}

local state = require("atlas.bitbucket.ui.panel.repository.state")
local renderer = require("atlas.bitbucket.ui.panel.repository.renderer")

---@param repo table|nil
function M.on_select(repo)
	state.set_current(repo)
	state.set_current_tab("overview")
	renderer.render(repo or {})
end

function M.refresh()
	local repo = state.current_repo
	if type(repo) == "table" then
		renderer.render(repo)
	end
end

---@param tab "overview"|"branches"|"tags"|"commits"
function M.select_tab(tab)
	state.set_current_tab(tab)
	M.refresh()
end

return M
