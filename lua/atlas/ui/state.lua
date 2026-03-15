--- @class UIState
--- @field win_id number|nil
--- @field buf_id number|nil
--- @field prev_win number|nil
--- @field current_view "jira"|"bitbucket"|"github"

--- @type UIState
local state = {
	win_id = nil,
	buf_id = nil,
	prev_win = nil,
	current_view = "jira",
}

return state
