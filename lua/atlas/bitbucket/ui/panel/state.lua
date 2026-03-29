---@class BitbucketPanelState
---@field current_pr_key string|nil
---@field current_pr table|nil
---@field current_pr_detail BitbucketPRDetail|nil
---@field current_tab "overview"|"commits"|"files"
local M = {
	current_pr_key = nil,
	current_pr = nil,
	current_pr_detail = nil,
	current_tab = "overview",
}

---@param pr table|nil
function M.set_current(pr)
	M.current_pr = pr
	if type(pr) == "table" and pr.id ~= nil then
		M.current_pr_key = tostring(pr.id)
	else
		M.current_pr_key = nil
	end
	M.current_pr_detail = nil
end

---@param detail BitbucketPRDetail|nil
function M.set_current_detail(detail)
	M.current_pr_detail = detail
end

---@param tab "overview"|"commits"|"files"
function M.set_current_tab(tab)
	if tab == "overview" or tab == "commits" or tab == "files" then
		M.current_tab = tab
	end
end

function M.reset_current()
	M.current_pr_key = nil
	M.current_pr = nil
	M.current_pr_detail = nil
	M.current_tab = "overview"
end

return M
