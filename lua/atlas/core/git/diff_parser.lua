local M = {}

---@class ParsedDiffLine
---@field text string    -- raw line text
---@field kind "add"|"remove"|"context"|"meta"

---@class ParsedDiffHunk
---@field header string        -- the @@ -x,y +a,b @@ line
---@field lines ParsedDiffLine[]

---@class ParsedDiffFile
---@field path string          -- display path (new path, or old path for deletions)
---@field old_path string|nil  -- only set for renames
---@field status "added"|"deleted"|"modified"|"renamed"
---@field hunks ParsedDiffHunk[]

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

---@param raw string
---@return string[]
local function split_lines(raw)
	local out = {}
	raw = raw:gsub("\r\n", "\n")
	for line in (raw .. "\n"):gmatch("(.-)\n") do
		table.insert(out, line)
	end
	return out
end

---@param file ParsedDiffFile
local function finalise_file(file)
	-- Deleted file: path was /dev/null on +++ side, use old_path
	if file.path == "" and file.old_path then
		file.path = file.old_path
		file.old_path = nil
		file.status = "deleted"
	end

	-- Rename: both sides set and differ
	if file.old_path and file.old_path ~= file.path and file.status == "modified" then
		file.status = "renamed"
	end
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

---Parse a raw unified diff string into a structured representation.
---All git-internal lines (diff --git, index, mode, --- a/, +++ b/) are consumed here
---@param raw string
---@return ParsedDiffFile[]
function M.parse(raw)
	if type(raw) ~= "string" or raw == "" then
		return {}
	end

	local files = {}
	---@type ParsedDiffFile|nil
	local cur_file = nil
	---@type ParsedDiffHunk|nil
	local cur_hunk = nil

	local function flush_hunk()
		if cur_hunk and cur_file then
			table.insert(cur_file.hunks, cur_hunk)
			cur_hunk = nil
		end
	end

	local function flush_file()
		flush_hunk()
		if cur_file then
			finalise_file(cur_file)
			table.insert(files, cur_file)
			cur_file = nil
		end
	end

	for _, line in ipairs(split_lines(raw)) do
		if line:match("^diff %-%-git ") then
			flush_file()
			cur_file = { path = "", old_path = nil, status = "modified", hunks = {} }
		elseif line:match("^new file mode") then
			if cur_file then
				cur_file.status = "added"
			end
		elseif line:match("^deleted file mode") then
			if cur_file then
				cur_file.status = "deleted"
			end
		elseif line:match("^rename from ") then
			if cur_file then
				cur_file.old_path = line:match("^rename from (.+)$")
				cur_file.status = "renamed"
			end
		elseif line:match("^rename to ") then
			if cur_file then
				cur_file.path = line:match("^rename to (.+)$")
			end
		elseif line:match("^%-%-%- ") then
			-- Extract old path; /dev/null means the file is new
			if cur_file then
				local p = line:match("^%-%-%- a/(.+)$") or line:match("^%-%-%- (.+)$")
				if p and p ~= "/dev/null" then
					cur_file.old_path = p
				end
			end
		elseif line:match("^%+%+%+ ") then
			-- Extract new path; /dev/null means the file is deleted
			if cur_file then
				local p = line:match("^%+%+%+ b/(.+)$") or line:match("^%+%+%+ (.+)$")
				if p and p ~= "/dev/null" then
					cur_file.path = p
				end
				-- /dev/null on +++ side is handled in finalise_file
			end
		elseif line:match("^@@ ") then
			flush_hunk()
			if cur_file then
				cur_hunk = { header = line, lines = {} }
			end
		elseif cur_hunk then
			local kind
			if line:match("^%+") then
				kind = "add"
			elseif line:match("^%-") then
				kind = "remove"
			elseif line:match("^\\ ") then
				kind = "meta" -- "\ No newline at end of file"
			else
				kind = "context"
			end
			table.insert(cur_hunk.lines, { text = line, kind = kind })
		elseif cur_file then
			-- Lines inside a file block but before the first hunk (index, mode
			-- change lines, binary notice, etc.) — intentionally dropped.
		else
			-- Lines before any "diff --git" (shouldn't happen with Bitbucket, but
			-- guard against truncated/non-standard responses by attaching them to
			-- a synthetic file entry so nothing is silently lost).
			if #files == 0 and cur_file == nil then
				cur_file = { path = "(unknown)", old_path = nil, status = "modified", hunks = {} }
				cur_hunk = { header = "", lines = {} }
			end
			if cur_hunk then
				table.insert(cur_hunk.lines, { text = line, kind = "context" })
			end
		end
	end

	flush_file()
	return files
end

return M
