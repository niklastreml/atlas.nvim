local M = {}

local utils = require("atlas.utils")
local spinner = require("atlas.ui.components.spinner")

---@param diffstat BitbucketPRDiffstat|"loading"|nil
---@param diff BitbucketPRDiff|"loading"|nil
---@param width integer|nil
---@return string[]
---@return table[]
function M.render(diffstat, diff, width)
	local lines = {}
	local spans = {}

	local diffstat_loading = diffstat == "loading"
	local diff_loading = diff == "loading"

	if diffstat_loading or diff_loading then
		local loading_line = spinner.with_text("Loading file changes...")
		table.insert(lines, loading_line)
		table.insert(spans, {
			line = 0,
			start_col = 0,
			end_col = #loading_line,
			hl_group = "AtlasTextMuted",
		})
		return lines, spans
	end

	local entries = (type(diffstat) == "table" and diffstat.entries) or {}
	local file_header = "Files"
	table.insert(lines, file_header)
	table.insert(spans, {
		line = #lines - 1,
		start_col = 0,
		end_col = #file_header,
		hl_group = "AtlasSectionHeader",
	})

	local added = 0
	local removed = 0
	for _, e in ipairs(entries) do
		added = added + (tonumber(e.lines_added) or 0)
		removed = removed + (tonumber(e.lines_removed) or 0)
	end

	local added_text = string.format("+%d added", added)
	local removed_text = string.format("-%d removed", removed)
	local stats_line = string.format("%s  %s", added_text, removed_text)
	local stats_line_index = #lines
	table.insert(lines, stats_line)
	table.insert(spans, {
		line = stats_line_index,
		start_col = 0,
		end_col = #added_text,
		hl_group = "AtlasTextPositive",
	})
	table.insert(spans, {
		line = stats_line_index,
		start_col = #added_text + 2,
		end_col = #stats_line,
		hl_group = "AtlasTextWarning",
	})
	table.insert(lines, "")

	if #entries == 0 then
		table.insert(lines, "No files changed.")
	else
		for _, entry in ipairs(entries) do
			local status = tostring(entry.status or ""):lower()
			local old_path = (type(entry.old_file) == "table" and tostring(entry.old_file.path or "")) or ""
			local new_path = (type(entry.new_file) == "table" and tostring(entry.new_file.path or "")) or ""

			local marker = "~"
			local hl_group = "AtlasTextMuted"
			local path = (new_path ~= "" and new_path) or old_path

			if status == "added" then
				marker = "+"
				hl_group = "AtlasTextPositive"
				path = (new_path ~= "" and new_path) or old_path
			elseif status == "removed" or status == "deleted" then
				marker = "-"
				hl_group = "AtlasTextWarning"
				path = (old_path ~= "" and old_path) or new_path
			elseif status == "renamed" then
				marker = "R"
				hl_group = "AtlasTextMuted"
				if old_path ~= "" and new_path ~= "" then
					path = string.format("%s -> %s", old_path, new_path)
				end
			end

			if path == "" then
				path = "(unknown file)"
			end

			local file_line = string.format("%s %s", marker, path)
			table.insert(lines, file_line)
			table.insert(spans, {
				line = #lines - 1,
				start_col = 0,
				end_col = 1,
				hl_group = hl_group,
			})
		end
	end
	table.insert(lines, "")

	local diff_text = (type(diff) == "table" and type(diff.text) == "string") and diff.text or ""
	if diff_text == "" then
		table.insert(lines, "No diff available.")
		return lines, spans
	end

	local diff_lines = utils.sanitize_lines(diff_text)
	for _, line in ipairs(diff_lines) do
		table.insert(lines, line)
		local idx = #lines - 1
		if line:match("^%+") and not line:match("^%+%+%+") then
			table.insert(spans, { line = idx, start_col = 0, end_col = #line, hl_group = "AtlasTextPositive" })
		elseif line:match("^%-") and not line:match("^%-%-%-") then
			table.insert(spans, { line = idx, start_col = 0, end_col = #line, hl_group = "AtlasTextWarning" })
		elseif line:match("^@@") then
			table.insert(spans, { line = idx, start_col = 0, end_col = #line, hl_group = "AtlasTextMuted" })
		end
	end

	return lines, spans
end

return M
