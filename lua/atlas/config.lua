--- Jira ---
---@class JiraViewConfig
---@field name string
---@field key string|nil
---@field jql string

---@class JiraCustomFieldConfig
---@field name string
---@field format fun(value: any): string|nil
---@field hl_group string|nil
---@field display "table"|"chip"|nil

--- @class JiraConfig
--- @field base_url string
--- @field email string
--- @field token string
--- @field cache_ttl number|nil
--- @field max_result number|nil
--- @field views JiraViewConfig[]|nil
--- @field resolve_parent_issues boolean|nil
--- @field project_config table<string, table<string, JiraCustomFieldConfig>>|nil

--- Bitbucket ---
---@class BitbucketRepoRef
---@field workspace string
---@field repo string

---@class BitbucketRepoSettings
---@field readme string|nil

---@class BitbucketRepoConfig
---@field settings table<string, BitbucketRepoSettings>|nil
---@field paths table<string, string>|nil

---@class BitbucketDiffConfig
---@field open_cmd "DiffviewOpen"|"CodeDiff"|string|nil

---@class BitbucketViewConfig
---@field name string
---@field key string|nil
---@field repos BitbucketRepoRef[]|nil
---@field layout "compact"|"plain"|nil
---@field filter? fun(pr: BitbucketPR, ctx: table): boolean

---@class BitbucketCustomActionContext
---@field repo_path string|nil
---@field pr BitbucketPR

---@class BitbucketCustomAction
---@field id string
---@field label string
---@field confirmation boolean|nil
---@field run fun(pr: BitbucketPR, ctx: BitbucketCustomActionContext, done: fun(ok: boolean|nil, message: string|nil))

--- @class BitbucketConfig
--- @field user string
--- @field token string
--- @field cache_ttl number|nil
--- @field views BitbucketViewConfig[]|nil
--- @field repo_config BitbucketRepoConfig|nil
--- @field diff BitbucketDiffConfig|nil
--- @field custom_actions BitbucketCustomAction[]|nil

--- @class AtlasConfig
--- @field jira JiraConfig
--- @field bitbucket BitbucketConfig
--- @field keymaps? AtlasKeymapsConfig

---@class AtlasKeymapsConfig
---@field ui? AtlasUIKeymaps
---@field jira? AtlasJiraKeymaps
---@field bitbucket? AtlasBitbucketKeymaps

local M = {}

---@type AtlasConfig
M.options = {
	jira = {
		base_url = vim.env.JIRA_BASE_URL or "",
		email = vim.env.JIRA_EMAIL or "",
		token = vim.env.JIRA_TOKEN or "",
		cache_ttl = 300,
		max_result = 100,
		resolve_parent_issues = false,
		views = nil,
		project_config = {},
	},

	bitbucket = {
		user = vim.env.BITBUCKET_USER or "",
		token = vim.env.BITBUCKET_TOKEN or "",
		cache_ttl = 300,
		views = nil,
		diff = {},
		repo_config = {
			settings = {},
			paths = {},
		},
		custom_actions = {},
	},

	keymaps = {
		ui = {
			help = "g?",
			close = "q",
			toggle_panel = "p",
			previous_panel_tab = "<S-Tab>",
			next_panel_tab = "<Tab>",
			refresh = "r",
		},
		jira = {
			open_actions = "A",
			search = "?",
			edit_issue = "ge",
			transition_issue = "gs",
			change_assignee = "ga",
			open_in_browser = "gx",
			create_issue = "c",
			manage_templates = "gT",
			refresh_issue = "r",
			refresh_view = "R",
			show_details = "K",
			copy_key = "y",
			copy_url = "Y",
			toggle_issue_children = "za",
		},
		bitbucket = {
			open_actions = "A",
			search = "?",
			toggle_repo_panel = "o",
			checkout_pr = "gc",
			open_diffview = "gd",
			open_in_browser = "gx",
			refresh_pr = "r",
			refresh_view = "R",
			show_details = "K",
			copy_id = "y",
			copy_url = "Y",
			pr_files_toggle_fold = "za",
			pr_files_next_hunk = "]h",
			pr_files_previous_hunk = "[h",
		},
	},
}

local function register_commands()
	pcall(vim.api.nvim_del_user_command, "AtlasJira", nil)
	pcall(vim.api.nvim_del_user_command, "AtlasJqlSearch", nil)
	pcall(vim.api.nvim_del_user_command, "AtlasBitbucket", nil)
	pcall(vim.api.nvim_del_user_command, "AtlasLogs", nil)
	pcall(vim.api.nvim_del_user_command, "AtlasClearCache", nil)

	vim.api.nvim_create_user_command("AtlasJira", function()
		require("atlas").open("jira")
	end, { desc = "Open Jira issue picker" })

	vim.api.nvim_create_user_command("AtlasJqlSearch", function(opts)
		require("atlas.jira.completion.search").command(opts)
	end, {
		desc = "Search Jira with text or JQL",
		nargs = "*",
		complete = function(arglead, cmdline, cursorpos)
			return require("atlas.jira.completion.search").complete(arglead, cmdline, cursorpos)
		end,
	})

	vim.api.nvim_create_user_command("AtlasBitbucket", function()
		require("atlas").open("bitbucket")
	end, { desc = "Open Bitbucket picker" })

	vim.api.nvim_create_user_command("AtlasLogs", function()
		require("atlas.ui.logs").toggle()
	end, { desc = "Open Atlas logs" })

	vim.api.nvim_create_user_command("AtlasClearCache", function()
		require("atlas.core.cache").clear_all()
		require("atlas.core.memory_cache").clear_all()
		vim.notify("Atlas cache cleared", vim.log.levels.INFO)
	end, { desc = "Clear Atlas disk and memory cache" })
end

---@param opts AtlasConfig|nil
function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.options, opts or {})
	register_commands()
end

return M
