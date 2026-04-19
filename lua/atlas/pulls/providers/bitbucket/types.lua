--------------------------------------------------------------------------------
-- Workspace
--------------------------------------------------------------------------------

---@class BitbucketWorkspace
---@field administrator boolean
---@field slug string
---@field uuid string
---@field links_self string|nil

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
