local M = {
	current_pr_key = nil,
	current_pr = nil,
	by_pr = {},
}

---@param pr_key string
function M.ensure(pr_key)
	if M.by_pr[pr_key] == nil then
		M.by_pr[pr_key] = {}
	end
	return M.by_pr[pr_key]
end

---@param pr table|nil
function M.set_current(pr)
	M.current_pr = pr
	if type(pr) == "table" and pr.id ~= nil then
		M.current_pr_key = tostring(pr.id)
		M.ensure(M.current_pr_key)
	else
		M.current_pr_key = nil
	end
end

function M.reset_current()
	M.current_pr_key = nil
	M.current_pr = nil
end

return M
