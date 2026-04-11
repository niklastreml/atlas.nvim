---@class BitbucketPRCommitsTabState
---@field pr BitbucketPR|nil
---@field commits BitbucketPRCommits|"loading"|nil
---@field commit_status_by_hash table<string, "successful"|"failed"|"inprogress"|"stopped"|"unknown"|"loading"|nil>
---@field commit_build_url_by_hash table<string, string|nil>
---@field line_map table<number, table>

---@class BitbucketPRCommitsTabState
local M = {
	pr = nil,
	commits = nil,
	commit_status_by_hash = {},
	commit_build_url_by_hash = {},
	line_map = {},
}

function M.reset()
	M.pr = nil
	M.commits = nil
	M.commit_status_by_hash = {}
	M.commit_build_url_by_hash = {}
	M.line_map = {}
end

return M
