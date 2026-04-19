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
---TODO: Should probably refactor once adding Github

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

--------------------------------------------------------------------------------
-- Pull request tasks
--------------------------------------------------------------------------------

---@class BitbucketPRTask
---@field id number
---@field state string
---@field content_raw string
---@field created_on string
---@field updated_on string
---@field resolved_on string|nil
---@field pending boolean|nil
---@field creator {name: string, nickname: string|nil, id: string|nil}
---@field comment_id number|nil
---@field links {self: string, html: string}
---@field comment_html string
