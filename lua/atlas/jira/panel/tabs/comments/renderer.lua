local M = {}
local state = require("atlas.jira.panel.tabs.comments.state")
local jira_state = require("atlas.jira.state")
local header = require("atlas.jira.panel.components.header")
local tabs = require("atlas.jira.panel.components.tabs")
local utils = require("atlas.utils")
local spinner = require("atlas.ui.components.spinner")
local comments_helper = require("atlas.jira.panel.tabs.comments.helper")
local icons = require("atlas.ui.utils.icons")
local threads = require("atlas.ui.components.threadsv2")
local highlights = require("atlas.ui.utils.highlights")

local PADDING_X = 1

---@param comments JiraComment[]
---@return JiraComment[]
local function root_comments(comments)
	local by_id = {}
	for _, comment in ipairs(comments or {}) do
		by_id[comment.id] = true
	end

	local roots = {}
	for _, comment in ipairs(comments or {}) do
		local pid = comment.parent_id
		if pid == nil or not by_id[tostring(pid)] then
			table.insert(roots, comment)
		end
	end

	return roots
end

---@param comment JiraComment
---@return AtlasThreadV2Item
local function to_thread_item(comment)
	local author = (comment.author ~= nil and comment.author.display_name) or "Unknown"
	local when = utils.relative_time_text(comment.created)
	local body = comment.body
	local can_edit = comments_helper.can_manage_comment(comment, jira_state.current_user)

	local footer_items = {
		string.format("%s (c)", icons.entity("reply")),
	}
	if can_edit then
		table.insert(footer_items, string.format("%s (e)", icons.entity("edit")))
		table.insert(footer_items, string.format("%s (d)", icons.entity("delete")))
	end

	local children = {}
	for _, child in ipairs(comment.children or {}) do
		table.insert(children, to_thread_item(child))
	end

	return {
		icon = icons.entity("user"),
		author = tostring(author),
		right_text = tostring(when),
		content = body,
		footer_items = footer_items,
		children = children,
		line_map = {
			comment = comment,
		},
		meta = {
			comment = comment,
			is_deleted = body == "Comment deleted",
		},
	}
end

---@param width integer
---@return string[], table[], table|nil
function M.render(width)
	local issue = state.issue
	if issue == nil then
		state.line_map = {}
		return { "", "  Nothing selected..." }, {}, state.line_map
	end

	local lines, spans = {}, {}
	local line_map = {}

	--- Header
	local header_lines, header_spans = header.render(issue, width)
	utils.append_block(lines, spans, { lines = header_lines, highlights = header_spans })
	utils.append_block(lines, spans, { lines = { "" }, highlights = {} })

	--- Tabs
	local tabs_lines, tabs_spans = tabs.render("comments", width, PADDING_X)
	utils.append_block(lines, spans, { lines = tabs_lines, highlights = tabs_spans })
	utils.append_block(lines, spans, { lines = { "" }, highlights = {} })

	--- Content
	local comments_count = state.comments ~= nil and #state.comments or 0
	local comments_title = string.rep(" ", PADDING_X) .. string.format("Comments (%d)", comments_count)
	table.insert(lines, comments_title)
	table.insert(spans, {
		line = #lines - 1,
		start_col = 0,
		end_col = #comments_title,
		hl_group = "AtlasTextMuted",
	})

	if state.comments ~= nil and #state.comments > 0 then
		local roots = root_comments(state.comments)
		local items = {}
		for _, comment in ipairs(roots) do
			table.insert(items, to_thread_item(comment))
		end

		local item_lines, item_spans, item_map = threads.render(items, width, {
			padding_x = PADDING_X,
			icon_hl_fn = function(item)
				local author = vim.trim(tostring(item.author or "")):lower()
				return highlights.dynamic_for(author) or "AtlasTextMuted"
			end,
			content_hl = function(item, row)
				local meta = item.meta or {}
				if meta.is_deleted then
					return {
						{ start_col = 0, end_col = #row, hl_group = "AtlasTextMutedItalic" },
					}
				end
				return nil
			end,
		})

		local offset = #lines
		utils.append_block(lines, spans, { lines = item_lines, highlights = item_spans })
		for lnum, entry in pairs(item_map or {}) do
			line_map[offset + lnum] = entry
		end
		table.insert(lines, "")
	elseif state.state ~= "loading" then
		table.insert(lines, string.rep(" ", PADDING_X) .. "No comments")
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #lines[#lines],
			hl_group = "AtlasTextMuted",
		})
	end

	if state.state == "loading" then
		local loading = string.rep(" ", PADDING_X) .. spinner.with_text("Loading comments...")
		table.insert(lines, loading)
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #loading,
			hl_group = "AtlasTextMuted",
		})
	end

	line_map[1] = line_map[1] or { kind = "issue", issue = issue }
	line_map[#lines] = line_map[#lines] or { kind = "comments" }
	state.line_map = line_map

	return lines, spans, state.line_map
end

return M
