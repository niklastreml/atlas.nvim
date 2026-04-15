--------------------------------------------------------------------------------
-- Keymaps
--------------------------------------------------------------------------------

---@alias AtlasKeymapValue string|string[]|false|nil

---@alias AtlasPullsProviderId "bitbucket"|"mock"|"github"
---@alias AtlasIssuesProviderId "jira"

--------------------------------------------------------------------------------
-- Domain Configs
--------------------------------------------------------------------------------

---@class AtlasPullsConfig
---@field bitbucket AtlasBitbucketPullsConfig|nil
---@field github table|nil

---@class AtlasIssuesConfig
---@field jira AtlasJiraIssuesConfig|nil

--------------------------------------------------------------------------------
-- Top-level Config
--------------------------------------------------------------------------------

---@class AtlasConfig
---@field pulls AtlasPullsConfig|nil
---@field issues AtlasIssuesConfig|nil
---@field keymaps AtlasKeymapsConfig|nil  -- see core/keymaps.lua for type

local M = {}

---@type AtlasConfig
M.options = {
	pulls = nil,
	issues = nil,
	keymaps = {
		ui = {
			help = "g?",
			close = "q",
			toggle_panel = "p",
			previous_panel_tab = "<S-Tab>",
			next_panel_tab = "<Tab>",
		},
		pulls = {
			refresh = "r",
			refresh_view = "R",
			open_actions = "A",
		},
		issues = {
			refresh = "r",
			refresh_view = "R",
		},
	},
}

--------------------------------------------------------------------------------
-- Legacy config migration
--------------------------------------------------------------------------------

---@param opts table
---@return table
local function migrate_legacy_config(opts)
	local migrated = vim.deepcopy(opts)

	local function warn(msg)
		vim.schedule(function()
			vim.notify("[Atlas] " .. msg, vim.log.levels.WARN)
		end)
	end

	if migrated.bitbucket and not migrated.pulls then
		warn("Legacy config: move 'bitbucket' into 'pulls.bitbucket'.")
		migrated.pulls = migrated.pulls or {}
		migrated.pulls.bitbucket = migrated.bitbucket
		migrated.bitbucket = nil
	end

	if migrated.jira and not migrated.issues then
		warn("Legacy config: move 'jira' into 'issues.jira'.")
		migrated.issues = migrated.issues or {}
		migrated.issues.jira = migrated.jira
		migrated.jira = nil
	end

	return migrated
end

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

local function register_commands()
	pcall(vim.api.nvim_del_user_command, "AtlasPulls")
	pcall(vim.api.nvim_del_user_command, "AtlasIssues")
	pcall(vim.api.nvim_del_user_command, "AtlasBitbucket")
	pcall(vim.api.nvim_del_user_command, "AtlasJira")
	pcall(vim.api.nvim_del_user_command, "AtlasLogs")
	pcall(vim.api.nvim_del_user_command, "AtlasClearCache")

	vim.api.nvim_create_user_command("AtlasLogs", function()
		require("atlas.ui.logs").toggle()
	end, { desc = "Toggle Atlas log viewer" })

	vim.api.nvim_create_user_command("AtlasClearCache", function()
		require("atlas.core.cache").clear_all()
		require("atlas.core.memory_cache").clear_all()
		vim.notify("Atlas cache cleared", vim.log.levels.INFO)
	end, { desc = "Clear Atlas disk and memory cache" })

	vim.api.nvim_create_user_command("AtlasPulls", function(opts)
		local provider_id = opts.fargs[1]
		require("atlas").open("pulls", provider_id)
	end, { desc = "Open Atlas pulls domain", nargs = "?" })

	vim.api.nvim_create_user_command("AtlasIssues", function(opts)
		local provider_id = opts.fargs[1]
		require("atlas").open("issues", provider_id)
	end, { desc = "Open Atlas issues domain", nargs = "?" })

	if M.options.pulls then
		if M.options.pulls.bitbucket then
			vim.api.nvim_create_user_command("AtlasBitbucket", function()
				require("atlas").open("pulls", "bitbucket")
			end, { desc = "Open Atlas Bitbucket pulls" })
		end

		if M.options.pulls.github then
			vim.api.nvim_create_user_command("AtlasGithub", function()
				require("atlas").open("pulls", "github")
			end, { desc = "Open Atlas GitHub pulls" })
		end
	end

	if M.options.issues then
		if M.options.issues.jira then
			vim.api.nvim_create_user_command("AtlasJira", function()
				require("atlas").open("issues", "jira")
			end, { desc = "Open Atlas Jira issues" })
		end
	end
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

---@param opts AtlasConfig|table|nil
function M.setup(opts)
	local resolved = migrate_legacy_config(opts or {})
	M.options = vim.tbl_deep_extend("force", M.options, resolved)
	register_commands()
end

return M
