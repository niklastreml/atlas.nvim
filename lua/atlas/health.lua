local M = {}

local config = require("atlas.config")
local checkout = require("atlas.bitbucket.checkout")

---@param section string
---@param user_key string
---@param token_key string
---@param label string
local function check_credentials(section, user_key, token_key, label)
	local opts = (config.options and config.options[section]) or {}
	local user = opts[user_key]
	local token = opts[token_key]

	if user and user ~= "" and token and token ~= "" then
		vim.health.ok(string.format("%s credentials configured", label))
		return
	end

	vim.health.warn(string.format("%s credentials missing (%s and/or %s)", label, user_key, token_key))
end

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

local function check_repo_paths()
	local bitbucket = (config.options and config.options.bitbucket) or {}
	local repo_paths = ((bitbucket.repo_config or {}).paths) or {}

	if vim.tbl_isempty(repo_paths) then
		vim.health.warn("bitbucket.repo_config.paths is empty (local checkout/custom actions may not work)")
		return
	end

	local ok, err = checkout.validate_repo_paths(repo_paths)
	if not ok then
		vim.health.error(string.format("bitbucket.repo_config.paths invalid: %s", tostring(err)))
		return
	end

	vim.health.ok(
		string.format(
			"bitbucket.repo_config.paths configured (%d mapping%s)",
			vim.tbl_count(repo_paths),
			vim.tbl_count(repo_paths) == 1 and "" or "s"
		)
	)
end

function M.check()
	--- Requirements
	vim.health.start("Requirements")
	if vim.fn.has("nvim-0.9") == 0 then
		vim.health.error("Neovim >= 0.9 required")
	else
		vim.health.ok("Neovim version compatible")
	end
	check_executable("git", true, "Git")

	vim.health.start("Bitbucket")
	check_repo_paths()
	check_credentials("bitbucket", "user", "token", "Bitbucket")

	vim.health.start("Jira")
	check_credentials("jira", "email", "token", "Jira")
end

return M
