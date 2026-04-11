---@class BitbucketRepoState
---@field detail BitbucketRepository|"loading"|nil
---@field tab "overview"|"branches"|"tags"
---@field item BitbucketRepository|nil

---@class BitbucketRepoState
local M = {
	detail = nil,
	tab = "overview",
	item = nil,
}

function M.reset()
	M.detail = nil
	M.tab = "overview"
	M.item = nil
end

return M
