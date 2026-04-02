local M = {}
local state = require("atlas.jira.panel.tabs.comments.state")
local jira_state = require("atlas.jira.state")
local header = require("atlas.jira.panel.components.header")
local tabs = require("atlas.jira.panel.components.tabs")
local utils = require("atlas.utils")
local spinner = require("atlas.ui.components.spinner")
local helper = require("atlas.jira.ui.helper")
local PADDING_X = 2

---@param comments JiraComment[]
---@return JiraComment[]
local function root_comments(comments)
	local by_id = {}
	for _, comment in ipairs(comments or {}) do
		if type(comment) == "table" then
			by_id[tostring(comment.id or "")] = true
		end
	end

	local roots = {}
	for _, comment in ipairs(comments or {}) do
		local pid = comment and comment.parent_id
		if pid == nil or not by_id[tostring(pid)] then
			table.insert(roots, comment)
		end
	end

	return roots
end

---@param lines string[]
---@param spans table[]
---@param line_map table<number, table>
---@param comment JiraComment
---@param depth integer
local function render_comment(lines, spans, line_map, comment, depth)
	local indent = string.rep(" ", PADDING_X + (depth * 3))
	local author = ((comment or {}).author or {}).display_name or "Unknown"
	local author_id = tostring((((comment or {}).author or {}).account_id) or "")
	local current_user_id = tostring(((jira_state.current_user or {}).account_id) or "")
	local can_edit = current_user_id ~= "" and author_id ~= "" and current_user_id == author_id
	local when = utils.relative_time_text((comment or {}).created)
	local meta = indent .. string.format("%s  %s", author, when)
	table.insert(lines, meta)
	line_map[#lines] = { kind = "comment", comment = comment }
	table.insert(spans, {
		line = #lines - 1,
		start_col = #indent,
		end_col = #indent + #author,
		hl_group = helper.person_hl(author),
	})
	table.insert(spans, {
		line = #lines - 1,
		start_col = #indent + #author,
		end_col = #meta,
		hl_group = "AtlasTextMuted",
	})

	local body = tostring((comment or {}).body or "")
	if body == "" then
		body = "-"
	end
	for _, row in ipairs(utils.sanitize_markdown_lines(body)) do
		table.insert(lines, indent .. row)
		line_map[#lines] = { kind = "comment", comment = comment }
	end

	local actions = "󰘍 Reply"
	if can_edit then
		actions = actions .. "   󰏫 Edit   󰆴 Delete"
	end
	local actions_line = indent .. actions
	table.insert(lines, actions_line)
	line_map[#lines] = { kind = "comment", comment = comment }
	table.insert(spans, {
		line = #lines - 1,
		start_col = 0,
		end_col = #actions_line,
		hl_group = "AtlasTextMuted",
	})

	for _, child in ipairs((comment and comment.children) or {}) do
		table.insert(lines, "")
		render_comment(lines, spans, line_map, child, depth + 1)
	end
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
	local comments_count = type(state.comments) == "table" and #state.comments or 0
	local comments_title = string.rep(" ", PADDING_X) .. string.format("Comments (%d)", comments_count)
	table.insert(lines, comments_title)
	table.insert(spans, {
		line = #lines - 1,
		start_col = 0,
		end_col = #comments_title,
		hl_group = "AtlasTextMuted",
	})
	table.insert(lines, "")

	if type(state.comments) == "table" and #state.comments > 0 then
		local roots = root_comments(state.comments)
		local sep_width = math.max(8, width - (PADDING_X * 2))
		local separator = string.rep(" ", PADDING_X) .. string.rep("─", sep_width)
		for idx, comment in ipairs(roots) do
			render_comment(lines, spans, line_map, comment, 0)
			if idx < #roots then
				table.insert(lines, separator)
				table.insert(spans, {
					line = #lines - 1,
					start_col = 0,
					end_col = #separator,
					hl_group = "AtlasTextMuted",
				})
			end
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
