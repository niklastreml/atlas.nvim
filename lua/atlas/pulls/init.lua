local M = {}

local main = require("atlas.pulls.ui.main")

---@param provider PullsProvider
function M.init(provider)
	main.init(provider)
end

function M.render()
	main.render()
end

return M
