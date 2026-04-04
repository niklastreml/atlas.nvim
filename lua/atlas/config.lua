--- Jira ---
---@class JiraViewConfig
---@field name string
---@field key string|nil
---@field jql string

--- @class JiraConfig
--- @field base_url string
--- @field email string
--- @field token string
--- @field cache_ttl number|nil
--- @field views JiraViewConfig[]|nil

--- Bitbucket ---
---@class BitbucketRepoConfig
---@field workspace string
---@field repo string
---@field readme string|nil

---@class BitbucketViewConfig
---@field name string
---@field key string|nil
---@field repos BitbucketRepoConfig[]|nil
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
--- @field repo_paths table<string, string>|nil
---@field custom_actions BitbucketCustomAction[]|nil

--- @class AtlasConfig
--- @field jira JiraConfig
--- @field bitbucket BitbucketConfig

local M = {}

---@type AtlasConfig
M.options = {
	jira = {
		base_url = vim.env.JIRA_BASE_URL or "",
		email = vim.env.JIRA_EMAIL or "",
		token = vim.env.JIRA_TOKEN or "",
		cache_ttl = 300,
		views = nil,
	},

	bitbucket = {
		user = vim.env.BITBUCKET_USER or "",
		token = vim.env.BITBUCKET_TOKEN or "",
		cache_ttl = 300,
		views = nil,
		repo_paths = {},
		custom_actions = {},
	},
}

local function normalize_views()
	if M.options.bitbucket.views and #M.options.bitbucket.views > 0 then
		for _, view in ipairs(M.options.bitbucket.views) do
			for _, repo in ipairs(view.repos or {}) do
				if repo.readme == nil or repo.readme == "" then
					repo.readme = "README.md"
				end
			end
		end
	end
end

local function register_commands()
	pcall(vim.api.nvim_del_user_command, "AtlasJira", nil)
	pcall(vim.api.nvim_del_user_command, "AtlasBitbucket", nil)
	pcall(vim.api.nvim_del_user_command, "AtlasLogs", nil)

	vim.api.nvim_create_user_command("AtlasJira", function()
		require("atlas").open("jira")
	end, { desc = "Open Jira issue picker" })

	vim.api.nvim_create_user_command("AtlasBitbucket", function()
		require("atlas").open("bitbucket")
	end, { desc = "Open Bitbucket picker" })

	vim.api.nvim_create_user_command("AtlasLogs", function()
		require("atlas.ui.logs").toggle()
	end, { desc = "Open Atlas logs" })
end

---@param opts AtlasConfig|nil
function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.options, opts or {})
	normalize_views()
	register_commands()
end

return M
