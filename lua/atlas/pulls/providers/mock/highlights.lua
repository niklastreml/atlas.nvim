local M = {}

---@type table<string, table>
local groups = {
	AtlasMockTheme = { bg = "#6d28d9", bold = true },
}

function M.setup()
	for name, opts in pairs(groups) do
		vim.api.nvim_set_hl(0, name, opts)
	end
end

return M
