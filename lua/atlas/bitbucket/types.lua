--------------------------------------------------------------------------------
-- Endpoint: GET /repositories/{{workspace}}/{{repo_slug}}/pullrequests?state=%s&pagelen=50
--------------------------------------------------------------------------------

---@class BitbucketPRAuthor
---@field name string
---@field account_id string
---@field nickname string

---@class BitbucketPRRepo
---@field name string
---@field link string
---@field workspace string
---@field repo string

---@class BitbucketPRLinks
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

---@class BitbucketPRSummary
---@field raw string
---@field html string

---@class BitbucketPR
---@field id number
---@field title string
---@field description string
---@field comments number
---@field tasks number
---@field author BitbucketPRAuthor
---@field is_draft boolean
---@field state string
---@field repo BitbucketPRRepo
---@field links BitbucketPRLinks
---@field summary BitbucketPRSummary
---@field source_branch string
---@field target_branch string
---@field source_commit_hash string
---@field close_source_branch boolean
---@field created_on string
---@field updated_on string
---@field _raw table

---@class BitbucketRepoPRGroup
---@field workspace string
---@field repo string
---@field full_name string
---@field pullrequests BitbucketPR[]

--------------------------------------------------------------------------------
-- Endpoint: GET /2.0/repositories/{workspace}/{repo_slug}/pullrequests/{id}
--------------------------------------------------------------------------------

---@class BitbucketPRParticipant
---@field account_id string
---@field name string
---@field nickname string
---@field role string
---@field approved boolean
---@field state string|nil
---@field participated_on string|nil

---@class BitbucketPRReviewerDecision
---@field account_id string
---@field name string
---@field nickname string
---@field decision "approved"|"changes_requested"|"pending"
---@field approved boolean
---@field participated_on string|nil

---@class BitbucketPRDetail: BitbucketPR
---@field reviewers BitbucketPRAuthor[]
---@field participants BitbucketPRParticipant[]
---@field decisions BitbucketPRReviewerDecision[]
---@field approvals_count number
---@field changes_requested_count number

--------------------------------------------------------------------------------
-- Endpoint: GET /2.0/repositories/{workspace}/{repo_slug}/diffstat/{workspace}/{repo_slug}
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
-- Endpoint: GET /2.0/repositories/{workspace}/{repo_slug}/pullrequests/{id}/commits
--------------------------------------------------------------------------------

---@class BitbucketPRCommit
---@field hash string
---@field short_hash string
---@field date string
---@field message string
---@field author_name string
---@field author_nickname string
---@field html_url string

---@class BitbucketPRCommits
---@field entries BitbucketPRCommit[]
---@field size number

--------------------------------------------------------------------------------
-- Endpoint: GET /2.0/repositories/{workspace}/{repo_slug}/diff/{workspace}/{repo_slug}:{src}%0D{dst}?from_pullrequest_id={id}&topic=true
--------------------------------------------------------------------------------

---@class BitbucketPRDiff
---@field text string

--------------------------------------------------------------------------------
-- Endpoint: GET /2.0/repositories/{workspace}/{repo_slug}/pullrequests/{id}/activity
--------------------------------------------------------------------------------

---@class BitbucketPRActivityActor
---@field name string
---@field account_id string
---@field nickname string

---@class BitbucketPRActivityUpdateEntry
---@field kind "update"
---@field date string
---@field actor BitbucketPRActivityActor
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
---@field actor BitbucketPRActivityActor

---@class BitbucketPRActivityCommentEntry
---@field kind "comment"
---@field date string
---@field updated_on string
---@field actor BitbucketPRActivityActor
---@field id number
---@field content_raw string
---@field deleted boolean
---@field pending boolean

---@alias BitbucketPRActivityEntry BitbucketPRActivityUpdateEntry|BitbucketPRActivityApprovalEntry|BitbucketPRActivityCommentEntry

---@class BitbucketPRActivity
---@field entries BitbucketPRActivityEntry[]
---@field size number

--------------------------------------------------------------------------------
-- Endpoint: GET /2.0/repositories/{workspace}/{repo_slug}/pullrequests/{id}/comments
--------------------------------------------------------------------------------

---@class BitbucketPRCommentAuthor
---@field name string
---@field account_id string
---@field nickname string

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
---@field code string

---@class BitbucketPRCommentEntry
---@field id number
---@field parent_id number|nil
---@field created_on string
---@field updated_on string
---@field content BitbucketPRCommentContent
---@field author BitbucketPRCommentAuthor
---@field deleted boolean
---@field pending boolean
---@field comment_type string
---@field links BitbucketPRCommentLinks
---@field inline BitbucketPRCommentInline|nil
---@field children BitbucketPRCommentEntry[]

---@class BitbucketPRComments
---@field entries BitbucketPRCommentEntry[]
---@field size number
---@field page number
---@field pagelen number

--------------------------------------------------------------------------------
-- Endpoint: GET /2.0/user/workspaces
--------------------------------------------------------------------------------

---@class BitbucketWorkspace
---@field slug string
---@field uuid string
---@field administrator boolean

--------------------------------------------------------------------------------
-- Endpoint: GET /2.0/repositories/{workspace}
--------------------------------------------------------------------------------

---@class BitbucketRepository
---@field uuid string
---@field name string
---@field full_name string
---@field slug string
---@field workspace string
---@field is_private boolean
---@field updated_on string

--------------------------------------------------------------------------------
-- Endpoint: GET /2.0/user
--------------------------------------------------------------------------------

---@class BitbucketCurrentUser
---@field type string
---@field created_on string
---@field display_name string
---@field nickname string
---@field username string
---@field uuid string
---@field account_id string
