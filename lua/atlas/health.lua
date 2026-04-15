local M = {}

local keymaps = require("atlas.core.keymaps")

---@param bin string
---@param required boolean
---@param label string
local function check_executable(bin, required, label)
	if vim.fn.executable(bin) == 1 then
		vim.health.ok(string.format("%s found: %s", label, bin))
		return
	end

	if required then
		vim.health.error(string.format("%s missing: %s", label, bin))
	else
		vim.health.warn(string.format("%s not found: %s", label, bin))
	end
end

local function validate_keymaps()
	local by_context = keymaps.validate()
	local context_names = vim.tbl_keys(by_context)
	table.sort(context_names)

	local has_conflicts = false
	for _, context_name in ipairs(context_names) do
		local conflicts = by_context[context_name] or {}
		local keys = vim.tbl_keys(conflicts)
		table.sort(keys)
		if #keys == 0 then
			vim.health.ok(string.format("%s: no conflicting mapped keys", context_name))
		else
			has_conflicts = true
			vim.health.warn(string.format("%s: %d conflicting key(s)", context_name, #keys))
			for _, key in ipairs(keys) do
				vim.health.warn(string.format("  %s -> %s", key, table.concat(conflicts[key], ", ")))
			end
		end
	end

	if not has_conflicts and #context_names == 0 then
		vim.health.ok("No conflicting mapped keys")
	end
end

function M.check()
	vim.health.start("Requirements")
	if vim.fn.has("nvim-0.10") == 0 then
		vim.health.error("Neovim >= 0.10 required")
	else
		vim.health.ok("Neovim version compatible")
	end
	check_executable("git", true, "Git")

	vim.health.start("Keymaps")
	validate_keymaps()
end

return M
