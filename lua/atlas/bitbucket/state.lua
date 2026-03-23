---@class BitbucketState
---@field active_view BitbucketViewConfig|nil
---@field current_view BitbucketViewConfig|nil
---@field is_loading boolean
---@field error string|nil
---@field repos BitbucketRepoPRGroup[]|nil

---@type BitbucketState
local M = {
	active_view = nil,
	current_view = nil,
	is_loading = false,
	error = nil,
	repos = nil,
}

return M
