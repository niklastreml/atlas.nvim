--------------------------------------------------------------------------------
-- Author
--------------------------------------------------------------------------------

---@class PullsAuthor
---@field name string
---@field id string
---@field username string

--------------------------------------------------------------------------------
-- Refs
--------------------------------------------------------------------------------

---@class PullsRef
---@field branch string
---@field commit_hash string

--------------------------------------------------------------------------------
-- Links
--------------------------------------------------------------------------------

---@class PullsLink
---@field html string

--------------------------------------------------------------------------------
-- Pull Request
--------------------------------------------------------------------------------

---@class PullRequest
---@field id string|number
---@field title string
---@field description string
---@field state "open"|"merged"|"declined"|"draft"
---@field author PullsAuthor
---@field source PullsRef
---@field destination PullsRef
---@field comments_count number
---@field tasks_count number
---@field created_on string
---@field updated_on string
---@field link PullsLink
---@field provider string
---@field repo_id string
---@field repo_name string
---@field _raw table|nil

--------------------------------------------------------------------------------
-- User (current authenticated user)
--------------------------------------------------------------------------------

---@class PullsUser
---@field name string
---@field id string
---@field username string

--------------------------------------------------------------------------------
-- Repository
--------------------------------------------------------------------------------

---@class PullsRepo
---@field id string
---@field name string

--------------------------------------------------------------------------------
-- Group (PRs grouped by repository)
--------------------------------------------------------------------------------

---@class PullsGroup
---@field repo PullsRepo
---@field prs PullRequest[]

--------------------------------------------------------------------------------
-- View
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Reviewer
--------------------------------------------------------------------------------

---@class PullsReviewer
---@field name string
---@field nickname string|nil
---@field decision "approved"|"changes_requested"|"pending"

--------------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------------

---@class PullsBuild
---@field name string
---@field state string
---@field url string|nil
---@field key string|nil

--------------------------------------------------------------------------------
-- Diffstat
--------------------------------------------------------------------------------

---@class PullsDiffstatEntry
---@field status "added"|"removed"|"renamed"|"modified"|"deleted"
---@field path string
---@field old_path string|nil
---@field lines_added number
---@field lines_removed number

--------------------------------------------------------------------------------
-- View
--------------------------------------------------------------------------------

---@class PullsView
---@field name string
---@field key string|nil
---@field provider_id AtlasPullsProviderId
---@field layout string|nil
---@field provider_view table
