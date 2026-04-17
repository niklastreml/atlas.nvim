local M = {}

---@type table<string, table>
local groups = {
	AtlasPROpen = { fg = "#0b1320", bg = "#93c5fd", bold = true },
	AtlasPRMerged = { fg = "#0b1320", bg = "#86efac", bold = true },
	AtlasPRDeclined = { fg = "#0b1320", bg = "#fca5a5", bold = true },
	AtlasPRDraft = { fg = "#111827", bg = "#fcd34d", bold = true },

	AtlasBuildLinkSuccess = { fg = "#a6da95", bold = true, underline = true },
	AtlasBuildLinkFailed = { fg = "#f38ba8", bold = true, underline = true },
	AtlasBuildLinkInProgress = { fg = "#f9e2af", bold = true, underline = true },
	AtlasBuildLinkMuted = { fg = "#7f849c", underline = true },
}

function M.setup()
	for name, opts in pairs(groups) do
		vim.api.nvim_set_hl(0, name, opts)
	end
end

return M
