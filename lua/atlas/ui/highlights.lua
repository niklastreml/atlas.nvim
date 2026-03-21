local M = {}

local palette = {
	blue = "#8aadf4",
	green = "#a6da95",
	orange = "#f5a97f",
	tab_inactive_bg = "#494d64",
	tab_inactive_fg = "#a5adcb",
	column_header = "#939ab7",
}

---@type table<string, table>
local groups = {
	AtlasTabActive = { bg = palette.blue, fg = "#1e1e2e", bold = true },
	AtlasTabInactive = { bg = palette.tab_inactive_bg, fg = palette.tab_inactive_fg },
	AtlasActionRefresh = { bg = palette.green, fg = "#1e1e2e", bold = true },
	AtlasActionHelp = { bg = palette.orange, fg = "#1e1e2e", bold = true },
	AtlasColumnHeader = { fg = palette.column_header, bold = true },

	AtlasTitleJira = { fg = "#0f172a", bg = "#38bdf8", bold = true },
	AtlasTitleBitbucket = { fg = "#e5e7eb", bg = "#2563eb", bold = true },
	AtlasTitleGithub = { fg = "#e5e7eb", bg = "#111827", bold = true },
}

function M.setup()
	for name, opts in pairs(groups) do
		vim.api.nvim_set_hl(0, name, opts)
	end
end

return M
