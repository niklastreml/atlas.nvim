local M = {}

local groups = {
	AtlasBitbucketStateOpen = { fg = "#86efac", bold = true },
	AtlasBitbucketStateDraft = { fg = "#fcd34d", bold = true },
	AtlasBitbucketStateMerged = { fg = "#94a3b8", bold = true },
}

function M.setup()
	for name, opts in pairs(groups) do
		vim.api.nvim_set_hl(0, name, opts)
	end
end

return M
