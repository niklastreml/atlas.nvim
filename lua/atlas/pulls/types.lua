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
---@field workspace string
---@field repo string
---@field repo_full_name string
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
-- Activity
--------------------------------------------------------------------------------

---@class PullsActivityEntry
---@field kind "approval"|"comment"|"update"|string
---@field actor {name: string, nickname: string|nil}|nil
---@field date string
---@field content_raw string|nil
---@field deleted boolean|nil
---@field changes table|nil
---@field source_branch string|nil
---@field target_branch string|nil

--------------------------------------------------------------------------------
-- Comment
--------------------------------------------------------------------------------

---@class PullsComment
---@field id number
---@field parent_id number|nil
---@field author {name: string, nickname: string|nil}|nil
---@field content_raw string
---@field created_on string
---@field deleted boolean|nil
---@field inline {path: string, to: number|nil, from: number|nil}|nil
---@field url string|nil

--------------------------------------------------------------------------------
-- Commit
--------------------------------------------------------------------------------

---@class PullsCommit
---@field hash string
---@field short_hash string|nil
---@field message string
---@field author_name string
---@field author_nickname string|nil
---@field date string
---@field html_url string|nil
---@field statuses_url string|nil

--------------------------------------------------------------------------------
-- Diff
--------------------------------------------------------------------------------

---@class PullsDiffFile
---@field path string
---@field old_path string|nil
---@field status string
---@field hunks PullsDiffHunk[]

---@class PullsDiffHunk
---@field header string
---@field lines PullsDiffLine[]

---@class PullsDiffLine
---@field kind "add"|"remove"|"context"|"meta"
---@field text string

