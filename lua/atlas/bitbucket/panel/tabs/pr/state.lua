---@class BitbucketPRState
---@field tab "overview"|"activity"|"comments"|"commits"|"files"
---@field item BitbucketPR|nil

---@class BitbucketPRState
local M = {
	tab = "overview",
	item = nil,
}

function M.reset()
	M.tab = "overview"
	M.item = nil
end

return M
