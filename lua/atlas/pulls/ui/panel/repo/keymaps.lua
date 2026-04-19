local M = {}

local help = require("atlas.ui.popups.help")

---@param buf integer
function M.register(buf)
	M.remove(buf)
	help.register("Panel", {
		{
			key = "r",
			desc = "Refresh tab",
			opts = { nowait = true, silent = true },
			callback = function()
				require("atlas.pulls.ui.panel").on_select(nil, nil, { force_refresh = true })
			end,
		},
	}, { index = 211, buffer = buf })
end

---@param buf integer
function M.remove(buf)
	help.remove("Panel", { { key = "r" } }, { buffer = buf })
end

return M
