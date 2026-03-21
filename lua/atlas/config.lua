--- Jira ---
---@class JiraViewConfig
---@field name string
---@field key string|nil
---@field jql string|nil

--- @class JiraConfig
--- @field base_url string
--- @field email string
--- @field token string
--- @field type string|nil
--- @field api_version string|nil
--- @field limit number|nil
--- @field cache_ttl number|nil
--- @field views JiraViewConfig[]|nil

--- Bitbucket ---
---@class BitbucketViewConfig
---@field name string
---@field key string|nil
---@field filter fun(pr: table, ctx: table): boolean|nil

--- @class BitbucketConfig
--- @field user string
--- @field token string
--- @field cache_ttl number|nil
--- @field views BitbucketViewConfig[]|nil

--- Github ---
---@class GithubViewConfig
---@field name string
---@field key string|nil
---@field filter fun(pr: table, ctx: table): boolean|nil
---
--- @class GithubConfig
--- @field token string
--- @field user string
--- @field cache_ttl number|nil
--- @field views GithubViewConfig[]|nil

--- @class AtlasConfig
--- @field jira JiraConfig
--- @field bitbucket BitbucketConfig
--- @field github GithubConfig

local M = {}

---@type AtlasConfig
M.options = {
	jira = {
		base_url = vim.env.JIRA_BASE_URL or "",
		email = vim.env.JIRA_EMAIL or "",
		token = vim.env.JIRA_TOKEN or "",
		type = vim.env.JIRA_AUTH_TYPE or "basic",
		api_version = vim.env.JIRA_API_VERSION or "3",
		limit = 200,
		cache_ttl = 300,
		views = nil,
	},

	bitbucket = {
		user = vim.env.BITBUCKET_USER or "",
		token = vim.env.BITBUCKET_TOKEN or "",
		cache_ttl = 300,
		views = nil,
	},
	github = {
		token = vim.env.GITHUB_TOKEN or "",
		user = vim.env.GITHUB_USER or "",
		cache_ttl = 300,
		views = nil,
	},
}

---@return JiraViewConfig
local function default_jira_views()
	return {
		{
			name = "Active Sprint",
			key = "S",
			jql = "project = '%s' AND (sprint in openSprints()) ORDER BY status ASC, assignee ASC, Rank ASC",
		},
	}
end

---@return BitbucketViewConfig
local function default_bitbucket_views()
	return {
		{
			name = "All",
			key = "A",
			filter = function(_, _)
				return true
			end,
		},
	}
end

---@return GithubViewConfig
local function default_github_views()
	return {
		{
			name = "All",
			key = "A",
			filter = function(_, _)
				return true
			end,
		},
	}
end

local function normalize_views()
	if not M.options.jira.views or #M.options.jira.views == 0 then
		M.options.jira.views = default_jira_views()
	end
	if not M.options.bitbucket.views or #M.options.bitbucket.views == 0 then
		M.options.bitbucket.views = default_bitbucket_views()
	end
	if not M.options.github.views or #M.options.github.views == 0 then
		M.options.github.views = default_github_views()
	end
end

local function register_commands()
	pcall(vim.api.nvim_del_user_command, "AtlasJira", nil)
	pcall(vim.api.nvim_del_user_command, "AtlasBitbucket", nil)
	pcall(vim.api.nvim_del_user_command, "AtlasGithub", nil)

	vim.api.nvim_create_user_command("AtlasJira", function()
		require("atlas.ui.renderer").render()
	end, { desc = "Open Jira issue picker" })

	vim.api.nvim_create_user_command("AtlasBitbucket", function()
		require("atlas.ui.renderer").render()
	end, { desc = "Open Bitbucket picker" })

	vim.api.nvim_create_user_command("AtlasGithub", function()
		require("atlas.ui.renderer").render()
	end, { desc = "Open Github picker" })
end

---@param opts AtlasConfig|nil
function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.options, opts or {})
	normalize_views()
	register_commands()
end

return M
