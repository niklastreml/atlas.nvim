local M = {}

---@type table<string, table>
local groups = {
	AtlasMockTheme = { fg = "#0b1320", bg = "#7dd3fc", bold = true },
}

function M.setup()
	for name, opts in pairs(groups) do
		vim.api.nvim_set_hl(0, name, opts)
	end
end

return M
