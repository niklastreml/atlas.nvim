---@class BitbucketState
---@field active_view BitbucketViewConfig|nil
---@field current_view BitbucketViewConfig|nil
---@field is_loading boolean
---@field error string|nil
---@field repos BitbucketRepoPRGroup[]|nil
---@field latest_request_tokens table<string, integer>
---@field request_seq integer

---@type BitbucketState
local M = {
	active_view = nil,
	current_view = nil,
	is_loading = false,
	error = nil,
	repos = nil,
	latest_request_tokens = {},
	request_seq = 0,
}

return M
