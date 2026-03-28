local M = {
	open = false,
	active_provider = nil,
	selected_item = nil,
}

---@param provider "bitbucket"|"jira"|"github"|nil
---@param item table|nil
function M.set_selection(provider, item)
	M.active_provider = provider
	M.selected_item = item
end

function M.clear_selection()
	M.active_provider = nil
	M.selected_item = nil
end

return M
