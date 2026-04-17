---@class PullsCommentsTab : PullsPanelTabModule
local M = {}

local utils = require("atlas.ui.shared.utils")
local icons = require("atlas.ui.shared.icons")
local highlights = require("atlas.ui.shared.highlights")
local spinner = require("atlas.ui.components.spinner")
local threads = require("atlas.ui.components.threadsv2")
local helper = require("atlas.pulls.ui.main.helper")
local state = require("atlas.pulls.ui.panel.tabs.comments.state")

local PADDING_X = 1

---@type { cancel: fun() }[]
local in_flight = {}

---@return PullsProvider|nil
local function get_provider()
	local pulls_state = require("atlas.pulls.state")
	return pulls_state.provider
end

local function cancel_all()
	for _, handle in ipairs(in_flight) do
		handle.cancel()
	end
	in_flight = {}
end

---@param handle { cancel: fun() }|nil
local function track(handle)
	if handle then
		table.insert(in_flight, handle)
	end
end

---@param value string|nil
---@return string
local function first_line(value)
	local raw = tostring(value or ""):gsub("\r\n", "\n")
	local line = raw:match("([^\n]+)") or raw
	return line
end

---@param author {name: string, nickname: string|nil}|nil
---@return string
local function author_name(author)
	if author == nil then
		return "Unknown"
	end
	if author.nickname and author.nickname ~= "" then
		return author.nickname
	end
	if author.name and author.name ~= "" then
		return author.name
	end
	return "Unknown"
end

---@param inline {path: string, to: number|nil, from: number|nil}|nil
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

---@class PullsCommentFileGroup
---@field file string
---@field nodes PullsCommentTreeNode[]

---@class PullsCommentTreeNode
---@field comment PullsComment
---@field children PullsCommentTreeNode[]

---@param comments PullsComment[]
---@return PullsCommentTreeNode[]
local function build_comment_tree(comments)
	local by_id = {}
	local roots = {}

	for _, c in ipairs(comments) do
		by_id[tonumber(c.id)] = { comment = c, children = {} }
	end

	for _, c in ipairs(comments) do
		local node = by_id[tonumber(c.id)]
		local parent_id = tonumber(c.parent_id)
		if parent_id ~= nil and by_id[parent_id] ~= nil then
			table.insert(by_id[parent_id].children, node)
		else
			table.insert(roots, node)
		end
	end

	return roots
end

---@param file string
---@param count integer
---@param pad integer
---@param max_width integer
---@return string line
---@return table[] spans
local function render_file_header(file, count, pad, max_width)
	local padding = string.rep(" ", pad)
	local count_suffix = string.format(" (%d)", count)
	local hdr_spans = {}

	if file == "PR" then
		local icon = icons.general("comment")
		local label = "Pull Request"
		local line = padding .. icon .. " " .. label .. count_suffix
		table.insert(hdr_spans, { line = 0, start_col = pad, end_col = #line, hl_group = "AtlasTextMuted" })
		return line, hdr_spans
	end

	local icon = icons.pulls("files")
	local prefix = padding .. icon .. " "
	local available = max_width - vim.api.nvim_strwidth(prefix) - vim.api.nvim_strwidth(count_suffix)
	if available < 1 then
		available = 1
	end
	local file_text = utils.truncate(file, available, true)
	local line = prefix .. file_text .. count_suffix
	table.insert(hdr_spans, { line = 0, start_col = pad, end_col = #line, hl_group = "AtlasTextMuted" })
	return line, hdr_spans
end

---@param node PullsCommentTreeNode
---@param file string
---@return AtlasThreadV2Item
local function to_thread_item(node, file)
	local comment = node.comment
	local is_deleted = comment.deleted == true
	local text = is_deleted and "(deleted comment)" or first_line(comment.content_raw)
	if text == "" then
		text = "(empty comment)"
	end

	local author = author_name(comment.author)
	local children = {}
	for _, child in ipairs(node.children or {}) do
		table.insert(children, to_thread_item(child, file))
	end

	return {
		icon = icons.general("user"),
		author = tostring(author),
		right_text = utils.relative_time(comment.created_on),
		content = text,
		children = children,
		line_map = {
			comment = comment,
			entity_kind = "comment",
			file = file,
		},
		meta = {
			comment = comment,
			author_hl_name = author,
			is_deleted = is_deleted,
		},
	}
end

---@param nodes PullsCommentTreeNode[]
---@return PullsCommentFileGroup[]
local function group_nodes_by_file(nodes)
	---@type table<string, PullsCommentFileGroup>
	local by_file = {}
	---@type PullsCommentFileGroup[]
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

---@param pr PullRequest
---@param repo PullsRepo|nil
---@param done fun()
function M.on_select(pr, repo, done)
	cancel_all()
	state.reset()

	local provider = get_provider()
	if not provider then
		return
	end

	if type(provider.fetch_comments) == "function" then
		state.comments = "loading"
		track(provider.fetch_comments(pr, function(comments, err)
			state.comments = err and err or (comments or {})
			done()
		end))
	end
end

---@param pr PullRequest
---@param width integer
---@return string[], table[], table<integer, table>|nil
function M.render(pr, width)
	local lines = {}
	local spans = {}
	local line_map = {}
	local max_width = math.max(20, width)

	if state.comments == nil then
		return lines, spans, line_map
	end

	-- Loading
	if state.comments == "loading" then
		utils.push(lines, spans, spinner.with_text("Loading comments..."), "AtlasTextMuted", PADDING_X)
		return lines, spans, line_map
	end

	-- Error
	if type(state.comments) == "string" then
		utils.push(lines, spans, state.comments, "AtlasLogError", PADDING_X)
		return lines, spans, line_map
	end

	-- Empty
	local comment_entries = state.comments
	if #comment_entries == 0 then
		utils.push(lines, spans, "No comments yet.", "AtlasTextMuted", PADDING_X)
		return lines, spans, line_map
	end

	local comment_nodes = build_comment_tree(comment_entries)
	local file_groups = group_nodes_by_file(comment_nodes)

	for group_index, group in ipairs(file_groups) do
		local fh_line, fh_spans = render_file_header(group.file, #group.nodes, PADDING_X, max_width)
		utils.append_block(lines, spans, { lines = { fh_line }, highlights = fh_spans })

		local items = {}
		for _, node in ipairs(group.nodes) do
			table.insert(items, to_thread_item(node, group.file))
		end

		local item_lines, item_spans, item_map = threads.render(items, max_width, {
			padding_x = PADDING_X,
			separator = "",
			additional_hl = function(item)
				return "AtlasTextMuted"
			end,
			author_hl = function(item, author)
				local meta = item and item.meta or nil
				local author_hl_name = meta and meta.author_hl_name or ""
				if type(author_hl_name) ~= "string" or vim.trim(author_hl_name) == "" then
					author_hl_name = author
				end
				return helper.author_hl(author_hl_name)
			end,
			icon_hl_fn = function(item)
				local meta = item and item.meta or nil
				local author_hl_name = meta and meta.author_hl_name or ""
				if type(author_hl_name) ~= "string" or vim.trim(author_hl_name) == "" then
					author_hl_name = tostring(item.author or "")
				end
				return helper.author_hl(author_hl_name)
			end,
			content_hl = function(item, row)
				local meta = item and item.meta or {}
				if meta.is_deleted then
					return {
						{ start_col = 0, end_col = #row, hl_group = "AtlasTextMutedItalic" },
					}
				end
				return nil
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

		if group_index < #file_groups then
			local pad = string.rep(" ", PADDING_X)
			local sep = pad .. string.rep("─", max_width - PADDING_X * 2)
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

	return lines, spans, line_map
end

return M
