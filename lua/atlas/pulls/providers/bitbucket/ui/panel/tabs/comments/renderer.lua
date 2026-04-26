local M = {}

local utils = require("atlas.ui.shared.utils")
local icons = require("atlas.ui.shared.icons")
local spinner = require("atlas.ui.components.spinner")
local threads = require("atlas.ui.components.threadsv2")
local helper = require("atlas.pulls.ui.main.helper")
local bb_helper = require("atlas.pulls.providers.bitbucket.ui.panel.tabs.comments.helper")
local author_completion = require("atlas.pulls.providers.bitbucket.completion.author")

local PADDING_X = 1

---@param value string|nil
---@return string
local function first_line(value)
	local raw = tostring(value or ""):gsub("\r\n", "\n")
	local line = raw:match("([^\n]+)") or raw
	return line
end

---@param value string|nil
---@return string
local function comment_display_text(value)
	return vim.trim(tostring(value or ""):gsub("\r\n", "\n"))
end

---@param pr PullRequest
---@param comments PullsComment[]|nil
---@param tasks BitbucketPRTask[]|nil
---@return PullsAuthor[]
local function mention_authors(pr, comments, tasks)
	---@type table<string, PullsAuthor>
	local seen = {}

	---@param author { name: string, nickname: string|nil, id: string|nil }|PullsAuthor|nil
	local function add(author)
		if type(author) ~= "table" then
			return
		end
		local id = tostring(author.id or "")
		if id == "" then
			return
		end
		if not seen[id] then
			seen[id] = {
				id = id,
				name = tostring(author.name or ""),
				username = tostring(author.nickname or author.username or ""),
			}
		end
	end

	add(pr.author)
	for _, c in ipairs(comments or {}) do
		add(c.author)
	end
	for _, t in ipairs(tasks or {}) do
		add(t.creator)
	end

	return vim.tbl_values(seen)
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

---@class BitbucketTaskMap
---@field by_comment_id table<number, BitbucketPRTask[]>
---@field global BitbucketPRTask[]

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
---@param task_map BitbucketTaskMap
---@param authors PullsAuthor[]
---@param current_user PullsUser|nil
---@return AtlasThreadV2Item
local function to_thread_item(node, file, task_map, authors, current_user)
	local comment = node.comment
	local is_deleted = comment.deleted == true
	local raw_text = is_deleted and "(deleted comment)" or comment_display_text(comment.content_raw)
	local text = author_completion.resolve(raw_text, authors)
	if text == "" then
		text = "(empty comment)"
	end

	local author = author_name(comment.author)
	local children = {}
	for _, child in ipairs(node.children or {}) do
		table.insert(children, to_thread_item(child, file, task_map, authors, current_user))
	end

	for _, task in ipairs((task_map.by_comment_id or {})[tonumber(comment.id) or -1] or {}) do
		local is_resolved = tostring(task.state or "") == "RESOLVED"
		local task_author = author_name(task.creator)
		local task_title = author_completion.resolve(first_line(task.content_raw), authors)
		if task_title == "" then
			task_title = "(empty task)"
		end
		local checkbox = is_resolved and "[x]" or "[ ]"
		local can_manage_task = bb_helper.can_manage_task(task, current_user)
		local footer_items = {
			string.format("%s (t)", is_resolved and icons.general("refresh") or icons.general("success")),
		}
		if can_manage_task then
			table.insert(footer_items, string.format("%s (e)", icons.general("edit")))
			table.insert(footer_items, string.format("%s (d)", icons.general("delete")))
		end
		table.insert(children, {
			icon = "",
			author = string.format("%s %s", checkbox, task_title),
			additional = string.format("by @%s", task_author),
			right_text = utils.relative_time(task.updated_on ~= "" and task.updated_on or task.created_on),
			content = nil,
			footer_items = footer_items,
			line_map = {
				task = task,
				entity_kind = "task",
				file = file,
			},
			meta = {
				task = task,
				author_hl_name = task_author,
				is_task = true,
				is_resolved = is_resolved,
			},
		})
	end

	local footer_items = {
		string.format("%s (c)", icons.general("reply")),
	}
	local is_own = current_user
		and comment.author
		and (comment.author.nickname == current_user.username or comment.author.name == current_user.name)
	if not is_deleted and is_own then
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

---@param tasks BitbucketPRTask[]|nil
---@return BitbucketTaskMap
local function build_task_map(tasks)
	local by_comment_id = {}
	local global = {}

	for _, task in ipairs(tasks or {}) do
		local comment_id = tonumber(task.comment_id)
		if comment_id ~= nil then
			by_comment_id[comment_id] = by_comment_id[comment_id] or {}
			table.insert(by_comment_id[comment_id], task)
		else
			table.insert(global, task)
		end
	end

	return {
		by_comment_id = by_comment_id,
		global = global,
	}
end

---@param task BitbucketPRTask
---@param authors PullsAuthor[]
---@param current_user PullsUser|nil
---@return AtlasThreadV2Item
local function to_global_task_item(task, authors, current_user)
	local is_resolved = tostring(task.state or "") == "RESOLVED"
	local checkbox = is_resolved and "[x]" or "[ ]"
	local title = author_completion.resolve(first_line(task.content_raw), authors)
	if title == "" then
		title = "(empty task)"
	end
	local can_manage_task = bb_helper.can_manage_task(task, current_user)
	local footer_items = {
		string.format("%s (t)", is_resolved and icons.general("refresh") or icons.general("success")),
	}
	if can_manage_task then
		table.insert(footer_items, string.format("%s (e)", icons.general("edit")))
		table.insert(footer_items, string.format("%s (d)", icons.general("delete")))
	end
	return {
		icon = "",
		author = string.format("%s %s", checkbox, title),
		additional = string.format("by @%s", author_name(task.creator)),
		right_text = utils.relative_time(task.updated_on ~= "" and task.updated_on or task.created_on),
		content = nil,
		footer_items = footer_items,
		line_map = {
			task = task,
			entity_kind = "task",
			file = "PR",
		},
		meta = {
			task = task,
			author_hl_name = author_name(task.creator),
			is_task = true,
			is_resolved = is_resolved,
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
---@param width integer
---@param comment_entries PullsComment[]|string|nil
---@param task_entries BitbucketPRTask[]|string|nil
---@return string[], table[], table<integer, table>|nil
function M.render(pr, width, comment_entries, task_entries)
	local lines = {}
	local spans = {}
	local line_map = {}
	local max_width = math.max(20, width)
	local current_user = require("atlas.pulls.state").current_user

	if comment_entries == nil and task_entries == nil then
		return lines, spans, line_map
	end

	if comment_entries == "loading" or task_entries == "loading" then
		utils.push(lines, spans, spinner.with_text("Loading comments..."), "AtlasTextMuted", PADDING_X)
		return lines, spans, line_map
	end

	if type(comment_entries) == "string" then
		utils.push(lines, spans, comment_entries, "AtlasLogError", PADDING_X)
		return lines, spans, line_map
	end

	local comments_tbl = type(comment_entries) == "table" and comment_entries or {}
	local tasks_tbl = type(task_entries) == "table" and task_entries or {}
	local authors = mention_authors(pr, comments_tbl, tasks_tbl)

	if #comments_tbl == 0 and #tasks_tbl == 0 then
		utils.push(lines, spans, "No comments yet.", "AtlasTextMuted", PADDING_X)
		return lines, spans, line_map
	end

	local comment_nodes = bb_helper.normalize_comments(comments_tbl)
	local task_map = build_task_map(tasks_tbl)

	if #tasks_tbl > 0 then
		local resolved_count = 0
		local unresolved_count = 0
		for _, task in ipairs(tasks_tbl) do
			if tostring(task.state or "") == "RESOLVED" then
				resolved_count = resolved_count + 1
			else
				unresolved_count = unresolved_count + 1
			end
		end

		local task_header = string.format("Tasks (%d/%d)", resolved_count, unresolved_count)
		table.insert(lines, string.rep(" ", PADDING_X) .. task_header)
		table.insert(spans, {
			line = #lines - 1,
			start_col = PADDING_X,
			end_col = PADDING_X + #task_header,
			hl_group = "AtlasColumnHeader",
		})

		local global_items = {}
		for _, task in ipairs(tasks_tbl) do
			table.insert(global_items, to_global_task_item(task, authors, current_user))
		end

		local item_lines, item_spans, item_map = threads.render(global_items, max_width, {
			padding_x = PADDING_X,
			separator = "",
			author_hl = function(item, author)
				local meta = item and item.meta or nil
				if meta and meta.is_task == true then
					return nil
				end
				local task = meta and meta.task or nil
				local name = task and author_name(task.creator) or author
				return helper.author_hl(name)
			end,
			additional_hl = function(item)
				local meta = item and item.meta or nil
				if meta and meta.is_task == true then
					local name = tostring(meta.author_hl_name or "")
					if name ~= "" then
						return helper.author_hl(name)
					end
				end
				return nil
			end,
			icon_hl_fn = function(item)
				local meta = item and item.meta or nil
				local task = meta and meta.task or nil
				local name = task and author_name(task.creator) or tostring(item.author or "")
				return helper.author_hl(name)
			end,
		})

		local offset = #lines
		utils.append_block(lines, spans, { lines = item_lines, highlights = item_spans })
		for lnum, entry in pairs(item_map or {}) do
			line_map[offset + lnum] = entry
		end

		table.insert(lines, "")
	end

	local file_groups = group_nodes_by_file(comment_nodes)
	for group_index, group in ipairs(file_groups) do
		local fh_line, fh_spans = render_file_header(group.file, #group.nodes, PADDING_X, max_width)
		utils.append_block(lines, spans, { lines = { fh_line }, highlights = fh_spans })

		local items = {}
		for _, node in ipairs(group.nodes) do
			table.insert(items, to_thread_item(node, group.file, task_map, authors, current_user))
		end

		local item_lines, item_spans, item_map = threads.render(items, max_width, {
			padding_x = PADDING_X,
			separator = "",
			additional_hl = function(item)
				local meta = item and item.meta or {}
				if meta.is_task == true then
					local name = tostring(meta.author_hl_name or "")
					if name ~= "" then
						return helper.author_hl(name)
					end
					return "AtlasTextMuted"
				end
				return "AtlasTextMuted"
			end,
			author_hl = function(item, author)
				local meta = item and item.meta or nil
				if meta and meta.is_task == true then
					return nil
				end
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
				if meta.is_task == true then
					return nil
				end
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
