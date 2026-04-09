local M = {}

local state = require("atlas.bitbucket.panel.tabs.pr.comments.state")
local panel_state = require("atlas.bitbucket.panel.state")
local header = require("atlas.bitbucket.panel.components.header")
local chips = require("atlas.bitbucket.panel.components.chips")
local bitbucket_helper = require("atlas.bitbucket.ui.helper")
local tabs_component = require("atlas.bitbucket.panel.components.tabs")
local utils = require("atlas.utils")
local spinner = require("atlas.ui.components.spinner")
local threads = require("atlas.ui.components.threads")

local PADDING_X = 2

---@class BitbucketCommentFileGroup
---@field file string
---@field nodes BitbucketPRCommentTreeNode[]

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
			author_hl_name = tostring((comment.author and comment.author.name) or ""),
			is_deleted = comment.deleted == true,
		},
	}
end

---@param nodes BitbucketPRCommentTreeNode[]
---@return BitbucketCommentFileGroup[]
local function group_nodes_by_file(nodes)
	---@type table<string, BitbucketCommentFileGroup>
	local by_file = {}
	---@type BitbucketCommentFileGroup[]
	local ordered = {}

	for _, node in ipairs(nodes or {}) do
		local file = file_label(node.comment.inline)
		local group = by_file[file]
		if group == nil then
			group = { file = file, nodes = {} }
			by_file[file] = group
			table.insert(ordered, group)
		end
		table.insert(group.nodes, node)
	end

	return ordered
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

	local file_groups = group_nodes_by_file(comment_nodes)
	for _, group in ipairs(file_groups) do
		local file = group.file
		local file_line = string.rep(" ", PADDING_X) .. file
		utils.append_block(lines, spans, {
			lines = { file_line },
			highlights = {
				{ line = 0, start_col = 0, end_col = #file_line, hl_group = "AtlasTextMuted" },
			},
		})

		for node_index, node in ipairs(group.nodes) do
			local item_lines, item_spans, item_map = threads.render({ to_thread_item(node, file) }, max_width, {
				padding_x = PADDING_X,
				author_hl = function(item, author)
					local meta = item and item.meta or nil
					local author_hl_name = meta and meta.author_hl_name or ""
					if type(author_hl_name) ~= "string" or vim.trim(author_hl_name) == "" then
						author_hl_name = author
					end

					return bitbucket_helper.author_hl(author_hl_name)
				end,
			})

			local offset = #lines
			utils.append_block(lines, spans, {
				lines = item_lines,
				highlights = item_spans,
			})
			for lnum, entry in pairs(item_map or {}) do
				line_map[offset + lnum] = entry
			end

			if node_index < #group.nodes then
				table.insert(lines, "")
			end
		end

		local separator = string.rep(" ", PADDING_X) .. string.rep("─", math.max(8, max_width - (PADDING_X * 2)))
		utils.append_block(lines, spans, {
			lines = { separator },
			highlights = {
				{ line = 0, start_col = 0, end_col = #separator, hl_group = "AtlasTextMuted" },
			},
		})
	end

	line_map[1] = line_map[1] or { kind = "pr", pr = pr }
	line_map[#lines] = line_map[#lines] or { kind = "comments" }

	state.line_map = line_map
	return lines, spans, line_map
end

return M
