---@class BitbucketPRState
---@field tab "overview"|"activity"|"comments"|"commits"|"files"
---@field item BitbucketPR|nil
---@field statuses BitbucketPRStatuses|"loading"|nil

---@class BitbucketPRState
local M = {
	tab = "overview",
	item = nil,
	statuses = nil,
}

function M.reset()
	M.tab = "overview"
	M.item = nil
	M.statuses = nil
end

return M
