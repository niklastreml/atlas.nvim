local M = {}

local config = require("atlas.config")
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

---@param section_path string[]
---@param user_key string
---@param token_key string
---@param label string
local function check_credentials(section_path, user_key, token_key, label)
	local opts = config.options
	for _, key in ipairs(section_path) do
		opts = type(opts) == "table" and opts[key] or nil
	end

	if type(opts) ~= "table" then
		vim.health.warn(string.format("%s not configured", label))
		return
	end

	local user = opts[user_key]
	local token = opts[token_key]
	if user and user ~= "" and token and token ~= "" then
		vim.health.ok(string.format("%s credentials configured", label))
		return
	end

	vim.health.warn(string.format("%s credentials missing (%s and/or %s)", label, user_key, token_key))
end

local function check_bitbucket()
	local pulls = config.options and config.options.pulls or nil
	local bb = pulls and pulls.providers and pulls.providers.bitbucket or nil
	if not bb then
		vim.health.info("Bitbucket not configured")
		return
	end

	check_credentials({ "pulls", "providers", "bitbucket" }, "user", "token", "Bitbucket")
end

local function check_pulls()
	local pulls = config.options and config.options.pulls or nil
	if not pulls then
		vim.health.info("Pulls not configured")
		return
	end

	local repo_paths = (pulls.repo_config or {}).paths or {}
	if vim.tbl_isempty(repo_paths) then
		vim.health.warn("pulls.repo_config.paths is empty")
	else
		vim.health.ok(string.format(
			"pulls.repo_config.paths configured (%d mapping%s)",
			vim.tbl_count(repo_paths),
			vim.tbl_count(repo_paths) == 1 and "" or "s"
		))
	end

	local diff_cmd = tostring((pulls.diff or {}).open_cmd or "")
	if diff_cmd == "" then
		vim.health.warn("pulls.diff.open_cmd is empty")
	elseif vim.fn.exists(":" .. diff_cmd) == 2 then
		vim.health.ok(string.format("pulls.diff.open_cmd available: %s", diff_cmd))
	else
		vim.health.error(string.format("pulls.diff.open_cmd not found: %s", diff_cmd))
	end
end
	end
end

local function check_jira()
	local issues = config.options and config.options.issues or nil
	local jira = issues and issues.jira or nil
	if not jira then
		vim.health.info("Jira not configured")
		return
	end

	check_credentials({ "issues", "jira" }, "email", "token", "Jira")

	local base_url = tostring(jira.base_url or "")
	if base_url == "" then
		vim.health.warn("jira.base_url is empty")
	elseif not base_url:match("^https://") then
		vim.health.warn(string.format("jira.base_url should start with https:// (current: %s)", base_url))
	else
		vim.health.ok("jira.base_url looks valid")
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

	vim.health.start("Pulls")
	check_pulls()

	vim.health.start("Bitbucket")
	check_bitbucket()

	vim.health.start("Jira")
	check_jira()

	vim.health.start("Keymaps")
	validate_keymaps()
end

return M
