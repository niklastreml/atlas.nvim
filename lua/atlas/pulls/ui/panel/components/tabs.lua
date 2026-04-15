local M = {}

local icons = require("atlas.shared.icons")
local tabs = require("atlas.ui.components.tabs")

local PR_TABS = {
	{ key = "overview", label = "Overview", icon = icons.general("overview") },
	{ key = "activity", label = "Activity", icon = icons.general("updated") },
	{ key = "comments", label = "Comments", icon = icons.general("comment") },
}

---@param active_tab string
---@param opts { width: integer, padding_x?: integer }
---@return string[], table[]
function M.render(active_tab, opts)
	return tabs.render(PR_TABS, active_tab, opts.width, {
		active_hl = nil,
		inactive_hl = "AtlasTextMuted",
		gap = " ",
		padding_x = opts.padding_x,
	})
end

return M
