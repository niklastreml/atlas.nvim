local M = {}

local utils = require("atlas.utils")
local table_view = require("atlas.ui.components.table")
local spinner = require("atlas.ui.components.spinner")
local highlights = require("atlas.ui.highlights")

---@param value string|nil
---@return string
local function first_line(value)
	local raw = tostring(value or ""):gsub("\r\n", "\n")
	return raw:match("([^\n]+)") or raw
end

---@param author BitbucketPRCommentAuthor|nil
---@return string
local function author_name(author)
	if type(author) ~= "table" then
		return "Unknown"
	end
	if type(author.nickname) == "string" and author.nickname ~= "" then
		return author.nickname
	end
	if type(author.name) == "string" and author.name ~= "" then
		return author.name
	end
	return "Unknown"
end

---@param inline BitbucketPRCommentInline|nil
---@return string
local function file_label(inline)
	if type(inline) ~= "table" then
		return "PR"
	end
	local path = tostring(inline.path or "")
	local line = inline["to"] or inline["from"]
	if path == "" then
		return "PR"
	end
	if type(line) == "number" then
		return string.format("%s:%d", path, line)
	end
	return path
end

---@param comment BitbucketPRCommentEntry
---@return table
local function to_tree_row(comment)
	local children = {}
	for _, child in ipairs(comment.children or {}) do
		table.insert(children, to_tree_row(child))
	end

	local status_parts = {}
	if comment.pending == true then
		table.insert(status_parts, "PENDING")
	end
	if comment.deleted == true then
		table.insert(status_parts, "DELETED")
	end

	local text = first_line((comment.content or {}).raw)
	if text == "" then
		text = "(empty comment)"
	end

	local author = author_name(comment.author)
	return {
		comment = text,
		status = table.concat(status_parts, " "),
		author = "@" .. author,
		date = utils.relative_time(comment.created_on),
		author_key = author,
		children = children,
		expanded = true,
	}
end

---@param entries BitbucketPRCommentEntry[]
---@return table<string, BitbucketPRCommentEntry[]>
---@return string[]
local function group_by_file(entries)
	local grouped = {}
	local order = {}

	for _, entry in ipairs(entries or {}) do
		local file = file_label(entry.inline)
		if grouped[file] == nil then
			grouped[file] = {}
			table.insert(order, file)
		end
		table.insert(grouped[file], entry)
	end

	return grouped, order
end

---@param comments BitbucketPRComments|"loading"|nil
---@param width integer|nil
---@return string[]
---@return table[]
function M.render(comments, width)
	local lines = {}
	local spans = {}
	local max_width = math.max(20, width or 60)

	if comments == "loading" then
		local loading_line = spinner.with_text("Loading comments...")
		table.insert(lines, loading_line)
		table.insert(spans, {
			line = 0,
			start_col = 0,
			end_col = #loading_line,
			hl_group = "AtlasTextMuted",
		})
		return lines, spans
	end

	local entries = (type(comments) == "table" and comments.entries) or {}
	if type(entries) ~= "table" or #entries == 0 then
		return { "No comments yet." }, spans
	end

	local grouped, order = group_by_file(entries)

	for idx, file in ipairs(order) do
		local header = file .. ":"
		table.insert(lines, header)
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #header,
			hl_group = "AtlasSectionHeader",
		})

		local rows = {}

		for _, entry in ipairs(grouped[file] or {}) do
			table.insert(rows, to_tree_row(entry))
		end

		local block_lines, _, block_spans = table_view.render({
			width = max_width,
			margin = 0,
			column_gap = 2,
			show_header = false,
			fill = true,
			columns = {
				{ key = "comment", name = "", min_width = 28, can_grow = true },
				{ key = "status", name = "", min_width = 8, can_grow = false },
				{ key = "author", name = "", min_width = 12, can_grow = false },
				{ key = "date", name = "", width = 4, can_grow = false },
			},
			rows = rows,
			tree = {
				children_key = "children",
				expanded_field = "expanded",
				default_expanded = true,
				indent = "  ",
				show_indicator = true,
				leaf_prefix = "↳ ",
			},
			cell_hl = function(row, col)
				if col.key == "author" then
					return highlights.dynamic_for(row.author_key)
				end
				if col.key == "date" then
					return "AtlasTextMuted"
				end
				if col.key == "status" and row.status ~= "" then
					return "AtlasTextWarning"
				end
				return nil
			end,
		})

		local base = #lines
		for _, line in ipairs(block_lines) do
			table.insert(lines, line)
		end
		for _, span in ipairs(block_spans or {}) do
			table.insert(spans, {
				line = base + span.line,
				start_col = span.start_col,
				end_col = span.end_col,
				hl_group = span.hl_group,
			})
		end

		while #lines > 0 and lines[#lines] == "" do
			table.remove(lines)
		end

		if idx < #order then
			local sep = string.rep("─", max_width)
			table.insert(lines, sep)
			table.insert(spans, {
				line = #lines - 1,
				start_col = 0,
				end_col = #sep,
				hl_group = "AtlasTextMuted",
			})
			table.insert(lines, "")
		end
	end

	return lines, spans
end

return M
