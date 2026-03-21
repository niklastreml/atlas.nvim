--- @class UIState
--- @field win_id number|nil
--- @field buf_id number|nil
--- @field prev_win number|nil
--- @field tab_id number|nil
--- @field current_view "jira"|"bitbucket"|"github"
--- @field line_map table<number, table>

--- @type UIState
local state = {
	win_id = nil,
	buf_id = nil,
	prev_win = nil,
	tab_id = nil,
	current_view = "jira",
	line_map = {},
}

return state
