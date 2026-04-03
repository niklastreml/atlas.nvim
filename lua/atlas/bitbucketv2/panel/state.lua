---@class BitbucketPanelState
---@field panel_type "pr"|"repo"|nil  -- Which panel context is active
---@field current_item table|nil       -- The selected PR or Repository
---@field current_tab string           -- Current tab key
---@field line_map table<number, table> -- Maps line numbers to interactive elements

---@class BitbucketPanelState
local M = {
	panel_type = nil,
	current_item = nil,
	current_tab = "overview",
	line_map = {},
}

---@param panel_type "pr"|"repo"|nil
function M.set_panel_type(panel_type)
	M.panel_type = panel_type
end

---@param item table|nil
function M.set_current_item(item)
	M.current_item = item
	M.line_map = {}
end

---@param tab_key string
function M.set_current_tab(tab_key)
	M.current_tab = tab_key
	M.line_map = {}
end

function M.reset()
	M.panel_type = nil
	M.current_item = nil
	M.current_tab = "overview"
	M.line_map = {}
end

return M
