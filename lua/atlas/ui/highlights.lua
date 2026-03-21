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

	AtlasText = { fg = "#cdd6f4" },
	AtlasTextMuted = { fg = "#7f849c" },
	AtlasTextSubtle = { fg = "#6c7086" },
	AtlasTextPositive = { fg = "#a6da95", bold = true },
	AtlasTextWarning = { fg = "#f9e2af", bold = true },
	AtlasTextDanger = { fg = "#f38ba8", bold = true },

	AtlasFooterBackground = { fg = "#cdd6f4", bg = "#202635" },
	AtlasFooterText = { fg = "#cdd6f4" },
	AtlasFooterMuted = { fg = "#7f849c" },
	AtlasFooterAccent = { fg = "#e2e8f0", bg = "#334155", bold = true },
	AtlasFooterInfo = { fg = "#89b4fa" },
	AtlasFooterSuccess = { fg = "#a6da95", bold = true },
	AtlasFooterWarning = { fg = "#f9e2af", bold = true },

	AtlasTitleJira = { fg = "#e2e8f0", bg = "#0f4c81", bold = true },
	AtlasTitleBitbucket = { fg = "#e2e8f0", bg = "#1e3a8a", bold = true },
	AtlasTitleGithub = { fg = "#e5e7eb", bg = "#111827", bold = true },
}

function M.setup()
	for name, opts in pairs(groups) do
		vim.api.nvim_set_hl(0, name, opts)
	end
end

return M
