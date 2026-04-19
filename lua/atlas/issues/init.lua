local M = {}

---@param provider IssuesProvider
function M.init(provider)
	local main = require("atlas.issues.ui.main")
	main.init(provider)
end

function M.render()
	local main = require("atlas.issues.ui.main")
	main.render()
end

return M
