local M = {}

local state = require("atlas.bitbucket.panel.tabs.pr.comments.state")
local panel_state = require("atlas.bitbucket.panel.state")
local header = require("atlas.bitbucket.panel.components.header")
local chips = require("atlas.bitbucket.panel.components.chips")
local tabs_component = require("atlas.bitbucket.panel.components.tabs")
local utils = require("atlas.utils")
local spinner = require("atlas.ui.components.spinner")
local threads = require("atlas.ui.components.threads")

local PADDING_X = 2

---@param value string|nil
---@return string
local function first_line(value)
	local raw = tostring(value or ""):gsub("\r\n", "\n")
	return raw:match("([^\n]+)") or raw
end

---@param author BitbucketPRAuthor|nil
---@return string
local function author_name(author)
	if author == nil then
		return "Unknown"
	end
	if author.nickname ~= "" then
		return author.nickname
	end
	if author.name ~= "" then
		return author.name
	end
	return "Unknown"
end

---@param inline BitbucketPRCommentInline|nil
---@return string
local function file_label(inline)
	if inline == nil then
		return "PR"
	end
	local path = inline.path
	local line = inline["to"] or inline["from"]
	if path == "" then
		return "PR"
	end
	if line ~= nil then
		return string.format("%s:%d", path, line)
	end
	return path
end

---@param node BitbucketPRCommentTreeNode
---@param file string
---@return AtlasThreadedItem
local function to_thread_item(node, file)
	local comment = node.comment
	local text = first_line(comment.content.raw)
	if text == "" then
		text = "(empty comment)"
	end

	local author = author_name(comment.author)
	local children = {}
	for _, child in ipairs(node.children or {}) do
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
	local tab_lines, tab_spans = tabs_component.render_pr(panel_state.current_tab, { width = width, padding_x = 1 })
	utils.append_block(lines, spans, { lines = tab_lines, highlights = tab_spans })
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

	local comment_nodes = comments or {}
	if #comment_nodes == 0 then
		table.insert(lines, "No comments yet.")
		state.line_map = line_map
		return lines, spans, line_map
	end

	for idx, node in ipairs(comment_nodes) do
		local file = file_label(node.comment.inline)
		local file_line = string.rep(" ", PADDING_X) .. file
		table.insert(lines, file_line)
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #file_line,
			hl_group = "AtlasTextMuted",
		})

		local item_lines, item_spans, item_map = threads.render({ to_thread_item(node, file) }, max_width, {
			padding_x = PADDING_X,
		})

		local offset = #lines
		for _, line in ipairs(item_lines) do
			table.insert(lines, line)
		end
		for _, span in ipairs(item_spans or {}) do
			table.insert(spans, {
				line = offset + span.line,
				start_col = span.start_col,
				end_col = span.end_col,
				hl_group = span.hl_group,
			})
		end
		for lnum, entry in pairs(item_map or {}) do
			line_map[offset + lnum] = entry
		end

		local separator = string.rep(" ", PADDING_X) .. string.rep("─", math.max(8, max_width - (PADDING_X * 2)))
		table.insert(lines, separator)
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #separator,
			hl_group = "AtlasTextMuted",
		})
	end

	line_map[1] = line_map[1] or { kind = "pr", pr = pr }
	line_map[#lines] = line_map[#lines] or { kind = "comments" }

	state.line_map = line_map
	return lines, spans, line_map
end

return M
