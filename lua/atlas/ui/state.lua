---@class UIState
---@field current_view string
---@field line_map table<number, table>

---@type UIState
local state = {
	current_view = "",
	line_map = {},
}

return state
