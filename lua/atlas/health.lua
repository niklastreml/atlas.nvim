local M = {}

local config = require("atlas.config")

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

function M.check()
	--- Requirements
	vim.health.start("Requirements")
	if vim.fn.has("nvim-0.9") == 0 then
		vim.health.error("Neovim >= 0.9 required")
	else
		vim.health.ok("Neovim version compatible")
	end

	vim.health.start("Provider Config")
	check_credentials("bitbucket", "user", "token", "Bitbucket")
	check_credentials("jira", "email", "token", "Jira")
	vim.health.warn("Github credentials check TODO")
end

return M
