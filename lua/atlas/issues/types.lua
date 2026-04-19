--------------------------------------------------------------------------------
-- User
--------------------------------------------------------------------------------

---@class IssueUser
---@field account_id string
---@field display_name string
---@field email string

--------------------------------------------------------------------------------
--  Issue
--------------------------------------------------------------------------------
--TODO: I should probably refactor when adding more providers since this is pretty Jira specific.

---@class Issue
---@field key string
---@field summary string
---@field project table|nil
---@field status string|nil
---@field status_id string|nil
---@field status_category string|nil
---@field status_color string|nil
---@field type table|nil
---@field priority string|nil
---@field assignee IssueUser|nil
---@field reporter string|nil
---@field story_points number|nil
---@field duedate string|nil
---@field parent Issue|nil

--------------------------------------------------------------------------------
-- Minimal for main view only
--------------------------------------------------------------------------------
