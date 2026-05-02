---@class PullsCommentsTab : PullsPanelTabModule
local M = {}

local utils = require("atlas.ui.shared.utils")
local icons = require("atlas.ui.shared.icons")
local spinner = require("atlas.ui.components.spinner")
local threads = require("atlas.ui.components.threadsv2")
local helper = require("atlas.pulls.ui.main.helper")
local core_utils = require("atlas.core.utils")
local md_editor = require("atlas.ui.popups.markdown_editor")
local footer = require("atlas.ui.components.footer")
local state = require("atlas.pulls.ui.panel.pr.tabs.comments.state")

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

	local function newest_in_tree(node)
		local newest = node.comment.created_on or ""
		for _, child in ipairs(node.children or {}) do
			local child_newest = newest_in_tree(child)
			if child_newest > newest then
				newest = child_newest
			end
		end
		return newest
	end

	table.sort(roots, function(a, b)
		return newest_in_tree(a) > newest_in_tree(b)
	end)

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
		local label = "Conversation"
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

---@param comment PullsComment
---@return boolean
local function is_own_comment(comment)
	local current_user = require("atlas.pulls.state").current_user
	if not current_user or not comment.author then
		return false
	end
	return comment.author.nickname == current_user.username or comment.author.name == current_user.name
end

---@param value string|nil
---@return string
local function comment_display_text(value)
	return utils.strip_markup(value)
end

---@param node PullsCommentTreeNode
---@param file string
---@return AtlasThreadV2Item
local function to_thread_item(node, file)
	local comment = node.comment
	local is_deleted = comment.deleted == true
	local text = is_deleted and "(deleted comment)" or comment_display_text(comment.content_raw)
	if text == "" then
		text = "(empty comment)"
	end

	local author = author_name(comment.author)
	local children = {}
	for _, child in ipairs(node.children or {}) do
		table.insert(children, to_thread_item(child, file))
	end

	local footer_items = {
		string.format("%s (c)", icons.general("reply")),
	}
	if not is_deleted and is_own_comment(comment) then
		table.insert(footer_items, string.format("%s (e)", icons.general("edit")))
		table.insert(footer_items, string.format("%s (d)", icons.general("delete")))
	end

	return {
		icon = icons.general("user"),
		author = tostring(author),
		right_text = utils.relative_time(comment.created_on),
		content = text,
		children = children,
		footer_items = footer_items,
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
---@param refresh fun()
---@param opts { force_refresh: boolean|nil }|nil
function M.on_select(pr, repo, refresh, opts)
	cancel_all()
	state.reset()

	local provider = get_provider()
	if not provider then
		return
	end

	local pr_id = tostring(pr.id or "")
	if type(provider.fetch_comments) == "function" then
		state.comments = "loading"
		footer.notify("loading", string.format("Loading comments for #%s...", pr_id))
		track(provider.fetch_comments(pr, opts, function(comments, err)
			if err then
				state.comments = err
				footer.notify("error", string.format("Failed to load comments for #%s", pr_id))
			else
				state.comments = comments or {}
				footer.notify("success", string.format("Comments loaded for #%s", pr_id), 1200)
			end
			refresh()
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

---@param _lnum integer
---@param entry table
---@return boolean
function M.is_selectable_line(_lnum, entry)
	local k = entry.kind
	return k == "header" or k == "content" or k == "thread_header" or k == "thread_content"
end

local keymaps = require("atlas.pulls.ui.panel.pr.tabs.comments.keymaps")
function M.activate(buf, refresh)
	if buf == nil or refresh == nil then
		return
	end
	keymaps.setup(buf, refresh)
end

---@param pr PullRequest
---@param refresh fun()
function M.add_comment(pr, refresh)
	local provider = get_provider()
	if not provider or type(provider.add_comment) ~= "function" then
		return
	end

	local completion = nil
	md_editor.open({
		key = "pr-comment-add",
		title = " Add Comment ",
		width_ratio = 0.5,
		height_ratio = 0.18,
		completion = completion,
		on_save = function(text)
			if not text or vim.trim(text) == "" then
				return
			end
			footer.notify("loading", "Adding comment...")
			track(provider.add_comment(pr, text, function(comment, err)
				if err then
					footer.notify("error", "Add comment failed: " .. err)
					return
				end
				if type(comment) == "table" and type(state.comments) == "table" then
					table.insert(state.comments, comment)
				end
				footer.notify("success", "Comment added", 1200)
				refresh()
			end))
		end,
	})
end

---@param pr PullRequest
---@param entry table
---@param refresh fun()
function M.reply_comment(pr, entry, refresh)
	local footer = require("atlas.ui.components.footer")
	local provider = get_provider()
	if not provider or type(provider.reply_comment) ~= "function" then
		return
	end

	local comment = entry.comment
	if not comment then
		return
	end

	local completion = nil
	local author = comment.author or {}
	local mention = tostring(author.nickname or author.name or "")
	local initial_text = mention ~= "" and ("@" .. mention .. " ") or ""
	md_editor.open({
		key = "pr-comment-reply-" .. tostring(comment.id),
		title = " Reply to Comment ",
		width_ratio = 0.5,
		height_ratio = 0.18,
		initial_text = initial_text,
		completion = completion,
		on_save = function(text)
			if not text or vim.trim(text) == "" then
				return
			end
			footer.notify("loading", "Sending reply...")
			track(provider.reply_comment(pr, comment.id, text, function(reply, err)
				if err then
					footer.notify("error", "Reply failed: " .. err)
					return
				end
				if type(reply) == "table" and type(state.comments) == "table" then
					table.insert(state.comments, reply)
				end
				footer.notify("success", "Reply added", 1200)
				refresh()
			end))
		end,
	})
end

---@param pr PullRequest
---@param entry table
---@param refresh fun()
function M.edit_comment(pr, entry, refresh)
	local footer = require("atlas.ui.components.footer")
	local provider = get_provider()
	if not provider or type(provider.edit_comment) ~= "function" then
		return
	end

	local comment = entry.comment
	if not comment or not is_own_comment(comment) then
		return
	end

	local completion = nil
	md_editor.open({
		key = "pr-comment-edit-" .. tostring(comment.id),
		title = " Edit Comment ",
		width_ratio = 0.5,
		height_ratio = 0.18,
		initial_text = comment.content_raw or "",
		completion = completion,
		on_save = function(text)
			if not text or vim.trim(text) == "" then
				return
			end
			footer.notify("loading", "Editing comment...")
			track(provider.edit_comment(pr, comment.id, text, function(updated, err)
				if err then
					footer.notify("error", "Edit failed: " .. err)
					return
				end
				local comments = core_utils.as_table(state.comments) or {}
				for i, c in ipairs(comments) do
					if c.id == comment.id then
						comments[i].content_raw = text
						break
					end
				end
				footer.notify("success", "Comment updated", 1200)
				refresh()
			end))
		end,
	})
end

---@param pr PullRequest
---@param entry table
---@param refresh fun()
function M.delete_comment(pr, entry, refresh)
	local provider = get_provider()
	if not provider or type(provider.delete_comment) ~= "function" then
		return
	end

	local comment = entry.comment
	if not comment or not is_own_comment(comment) then
		return
	end

	vim.ui.input({ prompt = "Delete comment? [y/N]: " }, function(input)
		local confirmed = input and vim.trim(input):lower()
		if confirmed ~= "y" and confirmed ~= "yes" then
			return
		end
		footer.notify("loading", "Deleting comment...")
		track(provider.delete_comment(pr, comment.id, function(ok, err)
			if err then
				footer.notify("error", "Delete failed: " .. err)
				return
			end
			if ok then
				local comments = core_utils.as_table(state.comments) or {}
				for i, c in ipairs(comments) do
					if c.id == comment.id then
						table.remove(comments, i)
						break
					end
				end
			end
			footer.notify("success", "Comment deleted", 1200)
			refresh()
		end))
	end)
end

function M.deactivate(buf)
	if buf ~= nil then
		keymaps.teardown(buf)
	end
	cancel_all()
end

return M
