--------------------------------------------------------------------------------
-- Keymaps
--------------------------------------------------------------------------------

---@alias AtlasKeymapValue string|string[]|false|nil

---@alias AtlasPullsProviderId "bitbucket"|"mock"|"github"
---@alias AtlasIssuesProviderId "jira"

--------------------------------------------------------------------------------
-- Pulls Provider Config
--------------------------------------------------------------------------------

---@class AtlasPullsViewConfig
---@field name string
---@field key string|nil
---@field layout "compact"|"plain"|nil

---@class AtlasIssuesViewConfig
---@field name string
---@field key string|nil

---@class AtlasPullsRepoConfig
---@field settings table<string, AtlasPullsRepoSettings>|nil
---@field paths table<string, string>|nil

---@class AtlasPullsRepoSettings
---@field readme string|nil

---@class AtlasPullsDiffConfig
---@field open_cmd "DiffviewOpen"|"CodeDiff"|string|nil

---@class AtlasPullsCustomActionContext
---@field repo_path string|nil
---@field pr PullRequest
---@field user PullsUser|nil

---@class AtlasPullsCustomAction
---@field id string
---@field label string
---@field confirmation boolean|nil
---@field run fun(pr: PullRequest, ctx: AtlasPullsCustomActionContext, done: fun(ok: boolean|nil, message: string|nil))

--------------------------------------------------------------------------------
-- Domain Configs
--------------------------------------------------------------------------------

---@class AtlasPullsProviders
---@field bitbucket AtlasBitbucketConfig|nil
---@field github table|nil

---@class AtlasPullsConfig
---@field repo_config AtlasPullsRepoConfig|nil
---@field diff AtlasPullsDiffConfig|nil
---@field custom_actions AtlasPullsCustomAction[]|nil
---@field providers AtlasPullsProviders|nil

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
			open_in_browser = "gx",
			copy_url = "Y",
			copy_id = "y",
			open_diff = "gd",
			checkout = "gc",
			show_details = "K",
			search = "?",
			pr_files_toggle_fold = "za",
			pr_files_next_hunk = "]h",
			pr_files_previous_hunk = "[h",
		},
		issues = {
			open_actions = "A",
			open_in_browser = "gx",
			copy_url = "Y",
			copy_key = "y",
			show_details = "<CR>",
			search = "?",
			toggle_issue_children = "za",
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
		warn("Legacy config: move 'bitbucket' into 'pulls.providers.bitbucket'.")
		migrated.pulls = migrated.pulls or {}
		migrated.pulls.providers = migrated.pulls.providers or {}
		migrated.pulls.providers.bitbucket = migrated.bitbucket
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

	if M.options.pulls and M.options.pulls.providers then
		if M.options.pulls.providers.bitbucket then
			vim.api.nvim_create_user_command("AtlasBitbucket", function()
				require("atlas").open("pulls", "bitbucket")
			end, { desc = "Open Atlas Bitbucket pulls" })
		end

		if M.options.pulls.providers.github then
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
