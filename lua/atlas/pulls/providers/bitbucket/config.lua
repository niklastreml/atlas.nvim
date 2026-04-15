---@class AtlasBitbucketRepoRef
---@field workspace string
---@field repo string

---@class AtlasBitbucketRepoSettings
---@field readme string|nil

---@class AtlasBitbucketRepoConfig
---@field settings table<string, AtlasBitbucketRepoSettings>|nil
---@field paths table<string, string>|nil

---@class AtlasBitbucketDiffConfig
---@field open_cmd "DiffviewOpen"|"CodeDiff"|string|nil

---@class AtlasBitbucketViewConfig
---@field name string
---@field key string|nil
---@field repos AtlasBitbucketRepoRef[]|nil
---@field layout "compact"|"plain"|nil
---@field filter? fun(pr: table, ctx: table): boolean

---@class AtlasBitbucketCustomAction
---@field id string
---@field label string
---@field confirmation boolean|nil
---@field run fun(pr: table, ctx: table, done: fun(ok: boolean|nil, message: string|nil))

---@class AtlasBitbucketPullsConfig
---@field user string
---@field token string
---@field cache_ttl number|nil
---@field views AtlasBitbucketViewConfig[]|nil
---@field repo_config AtlasBitbucketRepoConfig|nil
---@field diff AtlasBitbucketDiffConfig|nil
---@field custom_actions AtlasBitbucketCustomAction[]|nil
