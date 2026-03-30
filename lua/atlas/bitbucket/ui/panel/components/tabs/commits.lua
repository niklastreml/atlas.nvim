local M = {}

local utils = require("atlas.utils")
local icons = require("atlas.ui.icons")
local table_view = require("atlas.ui.components.table")
local spinner = require("atlas.ui.components.spinner")
local highlights = require("atlas.ui.highlights")

---@param commits BitbucketPRCommits|"loading"|nil
---@param width integer|nil
---@return string[]
---@return table[]
function M.render(commits, width)
	local lines = {}
	local spans = {}

	if commits == "loading" then
		local loading_line = spinner.with_text("Loading commits...")
		table.insert(lines, loading_line)
		table.insert(spans, {
			line = 0,
			start_col = 0,
			end_col = #loading_line,
			hl_group = "AtlasTextMuted",
		})
		return lines, spans
	end

	local entries = (type(commits) == "table" and commits.entries) or {}
	if type(entries) ~= "table" or #entries == 0 then
		return { "No commits yet." }, spans
	end

	local rows = {}
	for _, c in ipairs(entries) do
		local msg = tostring(c.message or ""):gsub("\r\n", "\n")
		msg = msg:match("([^\n]+)") or msg
		local author = (c.author_nickname ~= "" and c.author_nickname) or c.author_name or "Unknown"
		local hash = tostring(c.short_hash or c.hash or "")
		hash = hash:sub(1, 8)
		table.insert(rows, {
			icon = icons.entity("commit"),
			hash = hash,
			message = msg,
			author = author,
			date = utils.relative_time(c.date),
		})
	end

	local table_lines, _, table_spans = table_view.render({
		width = width,
		margin = 0,
		column_gap = 1,
		show_header = false,
		fill = true,
		columns = {
			{ key = "icon", name = "", width = 2, can_grow = false },
			{ key = "hash", name = "", width = 12, can_grow = false },
			{ key = "message", name = "", min_width = 24, can_grow = true },
			{ key = "author", name = "", can_grow = false },
			{ key = "date", name = "", width = 6, can_grow = false },
		},
		rows = rows,
		cell_hl = function(row, col)
			if col.key == "icon" then
				return "AtlasTextPositive"
			end
			if col.key == "hash" or col.key == "date" then
				return "AtlasTextMuted"
			end
			if col.key == "author" then
				return highlights.dynamic_for(row.author)
			end
			return nil
		end,
	})

	for _, line in ipairs(table_lines) do
		table.insert(lines, line)
	end
	for _, span in ipairs(table_spans or {}) do
		table.insert(spans, span)
	end

	return lines, spans
end

return M
