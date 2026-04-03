---@class BitbucketPRViewGroup
---@field workspace string
---@field repo string
---@field prs BitbucketPR[]

---@class BitbucketState
---@field active_view BitbucketViewConfig|nil
---@field current_view BitbucketViewConfig|nil
---@field pr_state string -- "OPEN", "MERGED", "DECLINED"
---@field is_loading boolean
---@field error string|nil
---@field current_user BitbucketCurrentUser|nil
---@field repos BitbucketPRViewGroup[]|nil
---@field pr_tree table[]|nil  -- Flat tree for main view rendering
---@field latest_request_tokens table<string, integer>
---@field request_seq integer

---@class BitbucketState
local M = {
	active_view = nil,
	current_view = nil,
	pr_state = "OPEN", --TODO: make configurable
	is_loading = false,
	error = nil,
	current_user = nil,
	repos = nil,
	pr_tree = nil,
	latest_request_tokens = {},
	request_seq = 0,
}

function M.reset()
	M.active_view = nil
	M.current_view = nil
	M.is_loading = false
	M.error = nil
	M.current_user = nil
	M.repos = nil
	M.pr_tree = nil
	M.latest_request_tokens = {}
	M.request_seq = 0
end

return M
