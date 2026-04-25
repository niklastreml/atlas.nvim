--------------------------------------------------------------------------------
-- Issue Type
--------------------------------------------------------------------------------

---@class JiraIssueType
---@field id string
---@field name string
---@field description string|nil
---@field subtask boolean
---@field entity_id string|nil

--------------------------------------------------------------------------------
-- Transition
--------------------------------------------------------------------------------

---@class JiraIssueTransition
---@field id string
---@field name string
---@field to_status_id string|nil
---@field to_status_name string|nil
---@field to_status_category string|nil
---@field to_status_color string|nil

---@class JiraIssueTransitionPage
---@field transitions JiraIssueTransition[]

--------------------------------------------------------------------------------
-- History
--------------------------------------------------------------------------------

---@class JiraIssueHistoryItem
---@field field string|nil
---@field field_type string|nil
---@field from string|nil
---@field from_string string|nil
---@field to string|nil
---@field to_string string|nil

---@class JiraIssueHistoryEntry
---@field id string
---@field created string|nil
---@field author IssueUser|nil
---@field items JiraIssueHistoryItem[]

---@class JiraIssueHistoryPage
---@field self string|nil
---@field start_at number
---@field max_results number
---@field total number
---@field is_last boolean
---@field values JiraIssueHistoryEntry[]
