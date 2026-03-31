---@class JiraIssue
---@field key string
---@field summary string
---@field status string
---@field status_category string
---@field type string
---@field priority string
---@field assignee string
---@field parent string|nil
---@field parent_summary string|nil
---@field story_points number|nil
---@field time_spent number|nil
---@field time_estimate number|nil
---@field labels string[]|nil

---@class JiraIssueDetail
---@field key string
---@field fields table

---@class JiraComment
---@field id string
---@field author string
---@field body table|string
---@field created string
---@field updated string

---@class JiraComments
---@field entries JiraComment[]

---@class JiraTransition
---@field id string
---@field name string
---@field to_status string

---@class JiraWorklog
---@field id string
---@field author string
---@field time_spent string
---@field started string
---@field comment table|string|nil

---@class JiraWorklogs
---@field entries JiraWorklog[]
