local M = {}

local state = require("atlas.bitbucket.panel.tabs.pr.comments.state")
local bitbucket_state = require("atlas.bitbucket.state")
local comments_helper = require("atlas.bitbucket.panel.tabs.pr.comments.helper")
local pr_state = require("atlas.bitbucket.panel.tabs.pr.state")
local header = require("atlas.bitbucket.panel.components.header")
local chips = require("atlas.bitbucket.panel.components.chips")
local bitbucket_helper = require("atlas.bitbucket.ui.helper")
local tabs_component = require("atlas.bitbucket.panel.components.tabs")
local utils = require("atlas.utils")
local spinner = require("atlas.ui.components.spinner")
local threads = require("atlas.ui.components.threadsv2")
local icons = require("atlas.ui.utils.icons")
local mention_completions = require("atlas.bitbucket.completion.author")

local PADDING_X = 1

---@class BitbucketCommentFileGroup
---@field file string
---@field nodes BitbucketPRCommentTreeNode[]

---@class BitbucketTaskMap
---@field by_comment_id table<number, BitbucketPRTask[]>
---@field global BitbucketPRTask[]

---@param value string|nil
---@return string
local function first_line(value)
	local raw = tostring(value or ""):gsub("\r\n", "\n")
	local line = raw:match("([^\n]+)") or raw
	return mention_completions.resolve(line)
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

---@param file string         File label (path or "PR")
---@param count integer       Number of comment threads in this group
---@param pad integer         Left padding
---@param max_width integer
---@return string line
---@return table[] spans
local function render_file_header(file, count, pad, max_width)
	local padding = string.rep(" ", pad)
	local count_suffix = string.format(" (%d)", count)
	local hdr_spans = {}

	if file == "PR" then
		local icon = icons.bitbucket_icon("bitbucket.entity.comment")
		local label = "Pull Request"
		local line = padding .. icon .. " " .. label .. count_suffix
		table.insert(hdr_spans, { line = 0, start_col = pad, end_col = #line, hl_group = "AtlasTextMuted" })
		return line, hdr_spans
	end

	local icon = icons.bitbucket_icon("bitbucket.entity.files")
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

---@param node BitbucketPRCommentTreeNode
---@param file string
---@param task_map BitbucketTaskMap
---@return AtlasThreadV2Item
local function to_thread_item(node, file, task_map)
	local comment = node.comment
	local is_deleted = comment.deleted == true
	local is_pending = comment.pending == true
	local can_manage = comments_helper.can_manage_comment(comment, bitbucket_state.current_user)
	local text = is_deleted and "(deleted comment)" or first_line(comment.content.raw)
	if text == "" then
		text = "(empty comment)"
	end

	local author = author_name(comment.author)
	local footer_items = {
		string.format("%s (c)", icons.jira_icon("jira.entity.reply")),
	}
	if can_manage then
		table.insert(footer_items, string.format("%s (e)", icons.jira_icon("jira.entity.edit")))
		table.insert(footer_items, string.format("%s (d)", icons.jira_icon("jira.entity.delete")))
	end
	local children = {}
	for _, child in ipairs(node.children or {}) do
		table.insert(children, to_thread_item(child, file, task_map))
	end

	for _, task in ipairs((task_map.by_comment_id or {})[tonumber(comment.id) or -1] or {}) do
		local is_resolved = tostring(task.state or "") == "RESOLVED"
		local task_author = author_name(task.creator)
		local task_title = first_line(task.content_raw)
		if task_title == "" then
			task_title = "(empty task)"
		end
		local checkbox = is_resolved and "[x]" or "[ ]"
		local can_manage_task = comments_helper.can_manage_task(task, bitbucket_state.current_user)
		local footer_items = {
			string.format("%s (t)", is_resolved and icons.entity("refresh") or icons.entity("success")),
		}
		if can_manage_task then
			table.insert(footer_items, string.format("%s (e)", icons.jira_icon("jira.entity.edit")))
			table.insert(footer_items, string.format("%s (d)", icons.jira_icon("jira.entity.delete")))
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

	return {
		icon = icons.bitbucket_icon("bitbucket.entity.user"),
		author = tostring(author),
		additional = is_pending and "PENDING" or nil,
		right_text = utils.relative_time(comment.created_on),
		content = text,
		footer_items = footer_items,
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
			is_pending = is_pending,
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
---@return AtlasThreadV2Item
local function to_global_task_item(task)
	local is_resolved = tostring(task.state or "") == "RESOLVED"
	local checkbox = is_resolved and "[x]" or "[ ]"
	local title = first_line(task.content_raw)
	if title == "" then
		title = "(empty task)"
	end
	local can_manage_task = comments_helper.can_manage_task(task, bitbucket_state.current_user)
	local footer_items = {
		string.format("%s (t)", is_resolved and icons.entity("refresh") or icons.entity("success")),
	}
	if can_manage_task then
		table.insert(footer_items, string.format("%s (e)", icons.jira_icon("jira.entity.edit")))
		table.insert(footer_items, string.format("%s (d)", icons.jira_icon("jira.entity.delete")))
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
	local max_width = math.max(20, width)

	local pr = state.pr
	local comments = state.comments
	local tasks = state.tasks

	if pr == nil then
		return { "", "  No PR selected..." }, {}, nil
	end

	-- Header
	local header_lines, header_spans = header.render(pr, width)
	utils.append_block(lines, spans, { lines = header_lines, highlights = header_spans })

	-- Chips
	local chip_line, chip_spans = chips.render(pr, pr_state.statuses)
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
	local tab_lines, tab_spans = tabs_component.render_pr(pr_state.tab, { width = width, padding_x = PADDING_X })
	utils.append_block(lines, spans, { lines = tab_lines, highlights = tab_spans })
	table.insert(lines, "")

	-- Comments content
	if comments == "loading" or tasks == "loading" then
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

	local comment_entries = type(comments) == "table" and comments or {}
	local task_entries = type(tasks) == "table" and tasks or {}
	if #comment_entries == 0 and #task_entries == 0 then
		local empty_line = string.rep(" ", PADDING_X) .. "No comments yet."
		table.insert(lines, empty_line)
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #empty_line,
			hl_group = "AtlasTextMuted",
		})
		state.line_map = line_map
		return lines, spans, line_map
	end

	local comment_nodes = comments_helper.normalize_comments(comment_entries)
	local task_map = build_task_map(task_entries)

	if #task_entries > 0 then
		local resolved_count = 0
		local unresolved_count = 0
		for _, task in ipairs(task_entries) do
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
		for _, task in ipairs(task_entries) do
			table.insert(global_items, to_global_task_item(task))
		end

		local item_lines, item_spans, item_map = threads.render(global_items, max_width, {
			padding_x = PADDING_X,
			separator = "",
			author_hl = function(item, author)
				local meta = item and item.meta or nil
				if meta and meta.is_task == true then
					return nil
				end
				local meta = item and item.meta or nil
				local task = meta and meta.task or nil
				local name = task and author_name(task.creator) or author
				return bitbucket_helper.author_hl(name)
			end,
			additional_hl = function(item, additional)
				local meta = item and item.meta or nil
				if meta and meta.is_task == true then
					local name = tostring(meta.author_hl_name or "")
					if name ~= "" then
						return bitbucket_helper.author_hl(name)
					end
				end
				return nil
			end,
			icon_hl_fn = function(item)
				local meta = item and item.meta or nil
				local task = meta and meta.task or nil
				local name = task and author_name(task.creator) or tostring(item.author or "")
				return bitbucket_helper.author_hl(name)
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
			table.insert(items, to_thread_item(node, group.file, task_map))
		end

		local item_lines, item_spans, item_map = threads.render(items, max_width, {
			padding_x = PADDING_X,
			additional_hl = function(item)
				local meta = item and item.meta or {}
				if meta.is_task == true then
					local name = tostring(meta.author_hl_name or "")
					if name ~= "" then
						return bitbucket_helper.author_hl(name)
					end
					return "AtlasTextMuted"
				end
				if meta.is_pending then
					return "AtlasLogWarn"
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
				return bitbucket_helper.author_hl(author_hl_name)
			end,
			icon_hl_fn = function(item)
				local meta = item and item.meta or nil
				local author_hl_name = meta and meta.author_hl_name or ""
				if type(author_hl_name) ~= "string" or vim.trim(author_hl_name) == "" then
					author_hl_name = tostring(item.author or "")
				end
				return bitbucket_helper.author_hl(author_hl_name)
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

	line_map[1] = line_map[1] or { kind = "pr", pr = pr }
	line_map[#lines] = line_map[#lines] or { kind = "comments" }

	state.line_map = line_map
	return lines, spans, line_map
end

return M
