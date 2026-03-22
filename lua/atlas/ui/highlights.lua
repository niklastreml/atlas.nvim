local M = {}

local palette = {
	blue = "#8aadf4",
	green = "#a6da95",
	orange = "#f5a97f",
	tab_inactive_bg = "#494d64",
	tab_inactive_fg = "#a5adcb",
	column_header = "#939ab7",

	bg_dark = "#1e1e2e",
	text = "#cdd6f4",
	text_muted = "#7f849c",
	text_subtle = "#6c7086",
	text_inverse = "#e2e8f0",
	text_inverse_soft = "#e5e7eb",

	warn = "#f9e2af",
	danger = "#f38ba8",
	info = "#89b4fa",

	footer_bg = "#202635",
	footer_accent_bg = "#334155",

	title_jira_bg = "#0f4c81",
	title_bitbucket_bg = "#1e3a8a",
	title_github_bg = "#111827",
}

---@type table<string, table>
local groups = {
	AtlasTabActive = { bg = palette.blue, fg = palette.bg_dark, bold = true },
	AtlasTabInactive = { bg = palette.tab_inactive_bg, fg = palette.tab_inactive_fg },
	AtlasActionRefresh = { bg = palette.green, fg = palette.bg_dark, bold = true },
	AtlasActionHelp = { bg = palette.orange, fg = palette.bg_dark, bold = true },
	AtlasColumnHeader = { fg = palette.column_header, bold = true },

	AtlasText = { fg = palette.text },
	AtlasTextMuted = { fg = palette.text_muted },
	AtlasTextSubtle = { fg = palette.text_subtle },
	AtlasTextPositive = { fg = palette.green, bold = true },
	AtlasTextWarning = { fg = palette.warn, bold = true },
	AtlasTextDanger = { fg = palette.danger, bold = true },

	AtlasFooterBackground = { fg = palette.text, bg = palette.footer_bg },

	AtlasTitleJira = { fg = palette.text_inverse, bg = palette.title_jira_bg, bold = true },
	AtlasTitleBitbucket = { fg = palette.text_inverse, bg = palette.title_bitbucket_bg, bold = true },
	AtlasTitleGithub = { fg = palette.text_inverse_soft, bg = palette.title_github_bg, bold = true },
}

M.palette = palette

function M.setup()
	for name, opts in pairs(groups) do
		vim.api.nvim_set_hl(0, name, opts)
	end
end

return M
