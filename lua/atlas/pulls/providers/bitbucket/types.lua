--------------------------------------------------------------------------------
-- Workspace
--------------------------------------------------------------------------------

---@class BitbucketWorkspace
---@field administrator boolean
---@field slug string
---@field uuid string
---@field links_self string|nil

--------------------------------------------------------------------------------
-- Repository
--------------------------------------------------------------------------------

---@class BitbucketRepository
---@field uuid string
---@field type string
---@field description string
---@field name string
---@field full_name string
---@field slug string
---@field workspace string
---@field is_private boolean
---@field updated_on string
---@field links { href: string, commits: string, branches: string, tags: string }
---@field size number
---@field created_on string
---@field mainbranch string
---@field readme string|nil
