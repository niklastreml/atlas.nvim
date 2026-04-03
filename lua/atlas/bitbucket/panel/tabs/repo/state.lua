---@class BitbucketRepoState
---@field detail BitbucketRepository|"loading"|nil

---@class BitbucketRepoState
local M = {
	detail = nil,
}

function M.reset()
	M.detail = nil
end

return M
