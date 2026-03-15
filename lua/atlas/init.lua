local M = {}

M.setup = function(opts)
	require("atlas.config").setup(opts)
  require("atlas.ui.highlights").setup()
end

return M
