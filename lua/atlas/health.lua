local M = {}

function M.check()
	--- Requirements
	vim.health.start("Requirements")
	if vim.fn.has("nvim-0.9") == 0 then
		vim.health.error("Neovim >= 0.9 required")
	else
		vim.health.ok("Neovim version compatible")
	end
end

return M
