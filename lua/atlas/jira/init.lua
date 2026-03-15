local M = {}

function M.open(_)
	require("atlas.ui.window").open({ title = " Jira", provider = "jira" })
	require("atlas.jira.renderer").render()
end

return M
