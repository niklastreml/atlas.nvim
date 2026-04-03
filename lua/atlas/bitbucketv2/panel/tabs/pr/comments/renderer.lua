local M = {}

local state = require("atlas.bitbucketv2.panel.tabs.pr.comments.state")
local panel_state = require("atlas.bitbucketv2.panel.state")
local header = require("atlas.bitbucketv2.panel.components.header")
local chips = require("atlas.bitbucketv2.panel.components.chips")
local tabs_component = require("atlas.bitbucketv2.panel.components.tabs")
local utils = require("atlas.utils")
local spinner = require("atlas.ui.components.spinner")
local highlights = require("atlas.ui.highlights")
local threads = require("atlas.ui.components.threads")

local PADDING_X = 2

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
---@param file string
---@return AtlasThreadedItem
local function to_thread_item(comment, file)
	local text = first_line((comment.content or {}).raw)
	if text == "" then
		text = "(empty comment)"
	end

	local author = author_name(comment.author)
	local children = {}
	for _, child in ipairs(comment.children or {}) do
		table.insert(children, to_thread_item(child, file))
	end

	return {
		author = tostring(author),
		timestamp = utils.relative_time(comment.created_on),
		content = text,
		children = children,
		line_map = {
			comment = comment,
			file = file,
		},
		meta = {
			comment = comment,
			is_deleted = comment.deleted == true,
		},
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

---@param thread_lines string[]
---@param thread_spans table[]
---@param thread_map table
---@return string[], table[], table
local function strip_root_separators(thread_lines, thread_spans, thread_map)
	local new_lines, new_spans, new_map = {}, {}, {}
	local remap = {}

	for old_lnum, line in ipairs(thread_lines or {}) do
		local map_entry = (thread_map or {})[old_lnum]
		local is_sep = map_entry == nil and tostring(line):match("^%s*─+$") ~= nil
		if not is_sep then
			table.insert(new_lines, line)
			remap[old_lnum] = #new_lines
		end
	end

	for _, span in ipairs(thread_spans or {}) do
		local old_lnum = (tonumber(span.line) or 0) + 1
		local new_lnum = remap[old_lnum]
		if new_lnum ~= nil then
			table.insert(new_spans, {
				line = new_lnum - 1,
				start_col = span.start_col,
				end_col = span.end_col,
				hl_group = span.hl_group,
			})
		end
	end

	for old_lnum, entry in pairs(thread_map or {}) do
		local new_lnum = remap[old_lnum]
		if new_lnum ~= nil then
			new_map[new_lnum] = entry
		end
	end

	return new_lines, new_spans, new_map
end

---@param width integer
---@return string[] lines
---@return table[] spans
---@return table|nil line_map
function M.render(width)
	local lines = {}
	local spans = {}
	local line_map = {}
	local max_width = math.max(20, width or 60)

	local pr = state.pr
	local comments = state.comments

	if pr == nil then
		return { "", "  No PR selected..." }, {}, nil
	end

	-- Header
	local header_lines, header_spans = header.render(pr, width)
	utils.append_block(lines, spans, { lines = header_lines, highlights = header_spans })

	-- Chips
	local chip_line, chip_spans = chips.render(pr)
	table.insert(lines, chip_line)
	local chip_base = #lines - 1
	for _, span in ipairs(chip_spans) do
		table.insert(spans, {
			line = chip_base,
			start_col = span.start_col,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end
	table.insert(lines, "")

	-- Tabs
	local tab_lines, tab_spans = tabs_component.render_pr(panel_state.current_tab, width, 0)
	local tab_base = #lines
	for _, line in ipairs(tab_lines) do
		table.insert(lines, line)
	end
	for _, span in ipairs(tab_spans) do
		table.insert(spans, {
			line = tab_base + span.line,
			start_col = span.start_col,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end
	table.insert(lines, "")

	-- Comments content
	if comments == "loading" then
		local loading_line = string.rep(" ", PADDING_X) .. spinner.with_text("Loading comments...")
		table.insert(lines, loading_line)
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #loading_line,
			hl_group = "AtlasTextMuted",
		})
		state.line_map = line_map
		return lines, spans, line_map
	end

	local entries = (type(comments) == "table" and comments.entries) or {}
	if type(entries) ~= "table" or #entries == 0 then
		table.insert(lines, "No comments yet.")
		state.line_map = line_map
		return lines, spans, line_map
	end

	local grouped, order = group_by_file(entries)

	for idx, file in ipairs(order) do
		local file_header = string.rep(" ", PADDING_X) .. file .. ":"
		table.insert(lines, file_header)
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #file_header,
				hl_group = "AtlasTextMuted",
		})

		local items = {}
		for _, entry in ipairs(grouped[file] or {}) do
			table.insert(items, to_thread_item(entry, file))
		end

		local item_lines, item_spans, item_map = threads.render(items, max_width, {
			padding_x = PADDING_X,
			author_hl = function(item, author)
				if type(author) ~= "string" or author == "" then
					return "AtlasTextMutedItalic"
				end
				local comment = ((item or {}).line_map or {}).comment
				local key = type(comment) == "table" and author_name(comment.author) or author
				return highlights.dynamic_for(key)
			end,
			content_hl = function(item, row)
				local meta = item.meta or {}
				if meta.is_deleted then
					return {
						{ start_col = 0, end_col = #row, hl_group = "AtlasTextMutedStrikethrough" },
					}
				end
				return nil
			end,
		})
		item_lines, item_spans, item_map = strip_root_separators(item_lines, item_spans, item_map)

		local offset = #lines
		utils.append_block(lines, spans, { lines = item_lines, highlights = item_spans })
		for lnum, entry in pairs(item_map or {}) do
			line_map[offset + lnum] = entry
		end

		while #lines > 0 and lines[#lines] == "" do
			table.remove(lines)
		end

		if idx < #order then
			table.insert(lines, "")
		end
	end

	line_map[1] = line_map[1] or { kind = "pr", pr = pr }
	line_map[#lines] = line_map[#lines] or { kind = "comments" }

	state.line_map = line_map
	return lines, spans, line_map
end

return M
