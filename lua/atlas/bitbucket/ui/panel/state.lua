---@class BitbucketPanelState
---@field current_pr table|nil
---@field current_pr_detail BitbucketPRDetail|{ loading: true }|nil
---@field current_tab "overview"|"commits"|"files"
local M = {
	current_pr = nil,
	current_pr_detail = nil,
	current_tab = "overview",
}

---@param pr table|nil
function M.set_current(pr)
	M.current_pr = pr
	M.current_pr_detail = nil
end

---@param detail BitbucketPRDetail|nil
function M.set_current_detail(detail)
	M.current_pr_detail = detail
end

function M.set_current_detail_loading()
	M.current_pr_detail = { loading = true }
end

---@param tab "overview"|"commits"|"files"
function M.set_current_tab(tab)
	if tab == "overview" or tab == "commits" or tab == "files" then
		M.current_tab = tab
	end
end

function M.reset_current()
	M.current_pr = nil
	M.current_pr_detail = nil
	M.current_tab = "overview"
end

return M
