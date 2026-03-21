--- @class UIState
--- @field win_id number|nil
--- @field buf_id number|nil
--- @field prev_win number|nil
--- @field tab_id number|nil
--- @field current_view "jira"|"bitbucket"|"github"
--- @field line_map table<number, table>
--- @field prev_laststatus number|nil
--- @field prev_ruler boolean|nil
--- @field prev_showcmd boolean|nil

--- @type UIState
local state = {
	win_id = nil,
	buf_id = nil,
	prev_win = nil,
	tab_id = nil,
	current_view = "jira",
	line_map = {},

	--- this is the annoying status bar that appears when you open a new window, we want to restore it to the previous value when closing the UI
	prev_laststatus = nil,
	prev_ruler = nil,
	prev_showcmd = nil,
}

return state
