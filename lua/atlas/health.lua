local M = {}

local config = require("atlas.config")
local checkout = require("atlas.core.git.checkout")
local keymaps = require("atlas.core.keymaps")

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
	local repo_paths = (bitbucket.repo_config or {}).paths or {}

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

local function check_diff_open_command()
	local bitbucket = (config.options and config.options.bitbucket) or {}
	local diff = bitbucket.diff or {}
	local cmd = tostring(diff.open_cmd or "")
	if cmd == "" then
		vim.health.warn("bitbucket.diff.open_cmd is empty")
		return
	end

	if vim.fn.exists(":" .. cmd) == 2 then
		vim.health.ok(string.format("bitbucket.diff.open_cmd available: %s", cmd))
		return
	end

	vim.health.error(string.format("bitbucket.diff.open_cmd not found: %s", cmd))
end

local function check_jira_base_url()
	local jira = (config.options and config.options.jira) or {}
	local base_url = tostring(jira.base_url or "")
	if base_url == "" then
		vim.health.warn("jira.base_url is empty")
		return
	end

	if not base_url:match("^https://") then
		vim.health.warn(string.format("jira.base_url should start with https:// (current: %s)", base_url))
		return
	end

	vim.health.ok("jira.base_url looks valid")
end

local function validate_keymaps()
	local by_context = keymaps.validate()
	local context_names = { "ui", "jira", "bitbucket" }

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
	--- Requirements
	vim.health.start("Requirements")
	if vim.fn.has("nvim-0.10") == 0 then
		vim.health.error("Neovim >= 0.10 required")
	else
		vim.health.ok("Neovim version compatible")
	end
	check_executable("git", true, "Git")

	vim.health.start("Bitbucket")
	check_repo_paths()
	check_credentials("bitbucket", "user", "token", "Bitbucket")
	check_diff_open_command()

	vim.health.start("Jira")
	check_credentials("jira", "email", "token", "Jira")
	check_jira_base_url()

	vim.health.start("Keymaps")
	validate_keymaps()
end

return M
