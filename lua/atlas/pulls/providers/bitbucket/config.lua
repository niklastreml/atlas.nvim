---@class AtlasBitbucketRepoRef
---@field workspace string
---@field repo string

---@class AtlasBitbucketViewConfig : AtlasPullsViewConfig
---@field repos AtlasBitbucketRepoRef[]|nil
---@field filter? fun(pr: PullRequest, user: PullsUser|nil): boolean|nil

---@class AtlasBitbucketConfig
---@field user string
---@field token string
---@field cache_ttl number|nil
---@field views AtlasBitbucketViewConfig[]|nil
