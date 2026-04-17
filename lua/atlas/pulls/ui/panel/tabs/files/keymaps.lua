local M = {}

local help = require("atlas.ui.popups.help")

---@param buf integer
---@param cursor_entry fun(): table|nil
---@param done fun()
function M.setup(buf, cursor_entry, done)
	local tab = require("atlas.pulls.ui.panel.tabs.files")

	local items = {
		{
			key = "za",
			desc = "Toggle hunk fold",
			opts = { nowait = true, silent = true },
			callback = function()
				local entry = cursor_entry()
				if entry then
					tab.toggle_hunk(entry)
					done()
				end
			end,
		},
		{
			key = "]h",
			desc = "Next hunk",
			opts = { nowait = true, silent = true },
			callback = function()
				tab.jump_hunk("next")
			end,
		},
		{
			key = "[h",
			desc = "Previous hunk",
			opts = { nowait = true, silent = true },
			callback = function()
				tab.jump_hunk("prev")
			end,
		},
	}

	help.register("Panel", items, { index = 212, buffer = buf })
end

---@param buf integer
function M.teardown(buf)
	help.remove("Panel", {
		{ key = "za" },
		{ key = "]h" },
		{ key = "[h" },
	}, { buffer = buf })
end

return M
