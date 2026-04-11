--------------------------------------------------------------------------------
-- User
--------------------------------------------------------------------------------

---@class BitbucketCurrentUser
---@field name string|nil
---@field account_id string|nil
---@field nickname string|nil
---@field display_name string
---@field username string|nil
---@field uuid string
---@field created_on string|nil

--------------------------------------------------------------------------------
-- Workspace
--------------------------------------------------------------------------------
---@class BitbucketWorkspace
---@field administrator boolean
---@field slug string
---@field uuid string
---@field links_self string|nil

--------------------------------------------------------------------------------
-- PullRequest
--------------------------------------------------------------------------------
---@class BitbucketPRAuthor
---@field name string
---@field account_id string
---@field nickname string

---@class BitbucketPRLinks
---@field html string
---@field self string
---@field merge string
---@field commits string
---@field approve string
---@field request_changes string
---@field diff string
---@field diffstat string
---@field comments string
---@field activity string
---@field statuses string

---@class BitbucketPRRef
---@field branch string
---@field commit_hash string

---@class BitbucketPR
---@field id number
---@field title string
---@field description string
---@field comments number
---@field tasks number
---@field author BitbucketPRAuthor
---@field is_draft boolean
---@field state  "OPEN"|"MERGED"|"DECLINED"
---@field links BitbucketPRLinks
---@field destination BitbucketPRRef
---@field source BitbucketPRRef
---@field close_source_branch boolean
---@field created_on string
---@field updated_on string
---@field workspace string
---@field repo string
---@field repo_slug string|nil
---@field repo_full_name string|nil

--------------------------------------------------------------------------------
-- PR Details
--------------------------------------------------------------------------------

---@class BitbucketPRParticipant: BitbucketPRAuthor
---@field role string
---@field approved boolean
---@field state "approved"|"changes_requested"|"pending"|nil
---@field participated_on string|nil

---@class BitbucketPRDetail: BitbucketPR
---@field reviewers BitbucketPRAuthor[]
---@field participants BitbucketPRParticipant[]
---@field approvals_count number
---@field changes_requested_count number

--------------------------------------------------------------------------------
-- PR Diff Stats
--------------------------------------------------------------------------------

---@class BitbucketPRDiffstatFile
---@field path string
---@field type string

---@class BitbucketPRDiffstatEntry
---@field status string
---@field lines_added number
---@field lines_removed number
---@field old_file BitbucketPRDiffstatFile|nil
---@field new_file BitbucketPRDiffstatFile|nil

---@class BitbucketPRDiffstat
---@field entries BitbucketPRDiffstatEntry[]
---@field size number

--------------------------------------------------------------------------------
-- PR Activity
--------------------------------------------------------------------------------

---@class BitbucketPRActivityUpdateEntry
---@field kind "update"
---@field date string
---@field actor BitbucketPRAuthor
---@field state string
---@field draft boolean
---@field title string
---@field description string
---@field reason string
---@field details string
---@field source_branch string
---@field target_branch string
---@field source_commit_hash string
---@field target_commit_hash string
---@field changes table

---@class BitbucketPRActivityApprovalEntry
---@field kind "approval"
---@field date string
---@field actor BitbucketPRAuthor

---@class BitbucketPRActivityCommentEntry
---@field kind "comment"
---@field date string
---@field updated_on string
---@field actor BitbucketPRAuthor
---@field id number
---@field content_raw string
---@field deleted boolean
---@field pending boolean

---@alias BitbucketPRActivityEntry BitbucketPRActivityUpdateEntry|BitbucketPRActivityApprovalEntry|BitbucketPRActivityCommentEntry

---@class BitbucketPRActivity
---@field entries BitbucketPRActivityEntry[]
---@field next string|nil

--------------------------------------------------------------------------------
-- Comments
--------------------------------------------------------------------------------

---@class BitbucketPRCommentContent
---@field type string
---@field raw string
---@field markup string
---@field html string

---@class BitbucketPRCommentInline
---@field from number|nil
---@field to number|nil
---@field path string
---@field start_from number|nil
---@field start_to number|nil

---@class BitbucketPRCommentLinks
---@field self string
---@field html string
---@field code string|nil

---@class BitbucketPRCommentEntry
---@field id number
---@field created_on string
---@field updated_on string
---@field content BitbucketPRCommentContent
---@field author BitbucketPRAuthor
---@field deleted boolean
---@field pending boolean
---@field comment_type string
---@field links BitbucketPRCommentLinks
---@field inline BitbucketPRCommentInline|nil

---@class BitbucketPRComments
---@field entries BitbucketPRCommentEntry[]
---@field size number|nil
---@field page number|nil
---@field pagelen number|nil
---@field next string|nil

--------------------------------------------------------------------------------
-- Tasks
--------------------------------------------------------------------------------

---@class BitbucketPRTask
---@field id number
---@field state "RESOLVED"|"UNRESOLVED"|string
---@field content_raw string
---@field created_on string
---@field updated_on string
---@field resolved_on string|nil
---@field pending boolean
---@field creator BitbucketPRAuthor
---@field comment_id number|nil
---@field links { self: string, html: string }
---@field comment_html string|nil

---@class BitbucketPRTasks
---@field entries BitbucketPRTask[]
---@field size number|nil
---@field page number|nil
---@field pagelen number|nil
---@field next string|nil

--------------------------------------------------------------------------------
-- Commits
--------------------------------------------------------------------------------

---@class BitbucketPRCommit
---@field hash string
---@field short_hash string
---@field date string
---@field message string
---@field author_name string
---@field author_nickname string
---@field html_url string
---@field statuses_url string

---@class BitbucketPRCommits
---@field entries BitbucketPRCommit[]
---@field page number

--------------------------------------------------------------------------------
-- Statuses
--------------------------------------------------------------------------------

---@class BitbucketPRStatus
---@field key string
---@field type string
---@field state "SUCCESSFUL"|"FAILED"|"INPROGRESS"|"STOPPED"|"UNKNOWN"
---@field name string
---@field refname string
---@field description string
---@field url string
---@field created_on string
---@field updated_on string
---@field commit_hash string

---@class BitbucketPRStatuses
---@field entries BitbucketPRStatus[]
---@field size number|nil

--------------------------------------------------------------------------------
-- Repository
--------------------------------------------------------------------------------
---@class BitbucketRepositoryLinks
---@field href string
---@field commits string
---@field branches string
---@field tags string

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
---@field links BitbucketRepositoryLinks
---@field size number
---@field created_on string
---@field mainbranch string
---@field readme string|nil

--------------------------------------------------------------------------------
-- Branches
--------------------------------------------------------------------------------

---@class BitbucketRepositoryBranch
---@field name string
---@field hash string
---@field date string
---@field message string
---@field author string

---@class BitbucketRepositoryBranches
---@field entries BitbucketRepositoryBranch[]

--------------------------------------------------------------------------------
-- Tags
--------------------------------------------------------------------------------

---@class BitbucketRepositoryTag
---@field name string
---@field hash string
---@field date string
---@field message string
---@field author string

---@class BitbucketRepositoryTags
---@field entries BitbucketRepositoryTag[]
