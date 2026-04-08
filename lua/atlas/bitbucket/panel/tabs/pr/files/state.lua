---@class BitbucketPRFilesTabState
---@field pr BitbucketPR|nil
---@field diff ParsedDiffFile[]|"loading"|nil
---@field line_map table<number, table>
---@field collapsed_hunks table<number, boolean>
---@field hunk_headers {hunk_idx: number, buf_line: number}[]

---@class BitbucketPRFilesTabState
local M = {
	pr = nil,
	diff = nil,
	line_map = {},
	collapsed_hunks = {},
	hunk_headers = {},
}

function M.reset()
	M.pr = nil
	M.diff = nil
	M.line_map = {}
	M.collapsed_hunks = {}
	M.hunk_headers = {}
end

return M
