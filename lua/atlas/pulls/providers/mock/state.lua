local M = {}

---@type table<string, { status: string, name: string }>
M.builds = {}

---@type table<string, any>
M.pending = {}

local STATUSES = { "successful", "failed", "inprogress", "stopped" }
local BUILD_NAMES = { "ci/build", "ci/lint", "ci/test", "deploy/staging" }

---@param pr PullRequest
---@return string
local function build_key(pr)
	return tostring(pr.repo_id or "") .. "/" .. tostring(pr.id or "")
end

---@param pr PullRequest
---@param on_done fun()
function M.fetch_build(pr, on_done)
	local key = build_key(pr)
	if M.builds[key] ~= nil then
		on_done()
		return
	end

	if M.pending[key] then
		return
	end

	M.pending[key] = true

	vim.defer_fn(function()
		M.pending[key] = nil
		M.builds[key] = {
			status = STATUSES[math.random(#STATUSES)],
			name = BUILD_NAMES[math.random(#BUILD_NAMES)],
		}
		on_done()
	end, 800 + math.random(600))
end

---@param pr PullRequest
---@return { status: string, name: string }|nil
function M.get_build(pr)
	return M.builds[build_key(pr)]
end

function M.reset()
	M.builds = {}
	M.pending = {}
end

return M
