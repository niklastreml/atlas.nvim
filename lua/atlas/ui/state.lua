--- @class UIState
--- @field current_view "jira"|"bitbucket"|"github"
--- @field line_map table<number, table>

--- @type UIState
local state = {
	current_view = "jira",
	line_map = {},
}

return state
