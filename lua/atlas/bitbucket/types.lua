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

---@class BitbucketPRLinks
---@field self string
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
