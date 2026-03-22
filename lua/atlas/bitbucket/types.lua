---@class BitbucketPRAuthor
---@field name string
---@field account_id string
---@field nickname string

---@class BitbucketPRRepo
---@field name string
---@field link string

---@class BitbucketPRLinks
---@field self string
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
