local M = {}
local state = require("atlas.jira.panel.tabs.history.state")
local header = require("atlas.jira.panel.components.header")
local tabs = require("atlas.jira.panel.components.tabs")
local utils = require("atlas.utils")
local spinner = require("atlas.ui.components.spinner")
local threads = require("atlas.ui.components.threads")
local highlights = require("atlas.ui.highlights")
local icons = require("atlas.ui.icons")
local jira_ui_helper = require("atlas.jira.ui.helper")
local PADDING_X = 2

---@param value string|nil
---@return string
local function format_estimate_value(value)
	if value == nil or value == "" then
		return utils.human_duration(0)
	end

	local n = tonumber(value)
	if n == nil then
		return tostring(value)
	end

	return utils.human_duration(n)
end

---@param item JiraIssueHistoryItem
---@return string|nil
local function item_header(item)
	---@return "added"|"deleted"|"updated"
	local function change_action()
		local from = item.from_string or item.from
		local to = item.to_string or item.to
		local has_from = type(from) == "string" and vim.trim(from) ~= ""
		local has_to = type(to) == "string" and vim.trim(to) ~= ""

		if has_from and not has_to then
			return "deleted"
		end

		if not has_from and has_to then
			return "added"
		end

		return "updated"
	end

	local field = item.field
	local action = change_action()

	if field == "Comment" then
		return string.format("%s a comment", action)
	end

	if field == "issuetype" then
		return string.format("%s issue type", action)
	end

	if field == "timeoriginalestimate" then
		return string.format("%s original estimate", action)
	end

	if field == "timeestimate" then
		return string.format("%s remaining estimate", action)
	end

	if field == "timespent" then
		return string.format("%s time spent", action)
	end

	if field == "WorklogId" then
		return string.format("%s worklog", action)
	end

	if field == "IssueParentAssociation" then
		return string.format("%s parent issue", action)
	end

	return string.format("%s %s", action, field)
end

---@param item JiraIssueHistoryItem
---@return string|nil
local function item_content(item)
	local field = item.field
	if field == "Comment" then
		return nil
	end

	if field == "description" then
		local from_value = item.from_string or item.from
		local to_value = item.to_string or item.to
		local from = type(from_value) == "string" and vim.trim(from_value:gsub("%s+", " ")) or ""
		local to = type(to_value) == "string" and vim.trim(to_value:gsub("%s+", " ")) or ""
		local has_from = from ~= ""
		local has_to = to ~= ""

		if has_from and has_to then
			return string.format("%s\n\n↓\n\n%s", from, to)
		end

		if has_from then
			return from
		end

		if has_to then
			return to
		end

		return nil
	end

	if field == "assignee" then
		local from = item.from_string or item.from or "Unassigned"
		local to = item.to_string or item.to or ""
		return string.format("%s %s -> %s %s", icons.entity("user"), tostring(from), icons.entity("user"), tostring(to))
	end

	if field == "priority" then
		local from = item.from_string or item.from or ""
		local to = item.to_string or item.to or ""
		local from_icon = icons.jira_icon(from)
		local to_icon = icons.jira_icon(to)
		return string.format("%s %s -> %s %s", from_icon, tostring(from), to_icon, tostring(to))
	end

	if field == "issuetype" then
		local from = item.from_string or item.from or ""
		local to = item.to_string or item.to or ""
		local from_icon = icons.jira_icon(from)
		local to_icon = icons.jira_icon(to)
		return string.format("%s %s -> %s %s", from_icon, tostring(from), to_icon, tostring(to))
	end

	if field == "timeoriginalestimate" or field == "timeestimate" or field == "timespent" then
		local from = format_estimate_value(item.from_string or item.from)
		local to = format_estimate_value(item.to_string or item.to)
		return string.format("%s -> %s", from, to)
	end

	if field == "IssueParentAssociation" then
		local from = item.from_string or item.from
		local to = item.to_string or item.to
		local from_text = (type(from) == "string" and vim.trim(from) ~= "") and from or "None"
		local to_text = (type(to) == "string" and vim.trim(to) ~= "") and to or "None"
		return string.format("%s -> %s", tostring(from_text), tostring(to_text))
	end

	local from = item.from_string or item.from or ""
	local to = item.to_string or item.to or ""
	return string.format("%s -> %s", tostring(from), tostring(to))
end

---@param item JiraIssueHistoryItem
---@return string[]|nil
local function item_footer(item)
	return nil
end

---@param item AtlasThreadedItem
---@param _text string
---@return string|nil
local function header_content_hl(item, _text)
	local history_item = ((item or {}).line_map or {}).history_item
	if history_item == nil then
		return nil
	end

	local field = history_item.field
	if field == "timeoriginalestimate" or field == "timeestimate" or field == "timespent" then
		return highlights.dynamic_for("time")
	end

	return highlights.dynamic_for(field:lower())
end

---@param item AtlasThreadedItem
---@param row string
---@param row_index integer
---@return table[]|nil
local function content_hl(item, row, row_index)
	local history_item = ((item or {}).line_map or {}).history_item
	if history_item == nil then
		return nil
	end

	local field = history_item.field
	if field == "description" then
		local from_value = history_item.from_string or history_item.from
		local to_value = history_item.to_string or history_item.to
		local from = type(from_value) == "string" and vim.trim(from_value:gsub("%s+", " ")) or ""
		local to = type(to_value) == "string" and vim.trim(to_value:gsub("%s+", " ")) or ""
		local has_from = from ~= ""
		local has_to = to ~= ""
		local old_line_count = has_from and 1 or 0

		if has_from and row_index <= old_line_count then
			return {
				{ start_col = 0, end_col = #row, hl_group = "AtlasTextMutedStrikethrough" },
			}
		end

		return nil
	end

	if field == "assignee" or field == "priority" or field == "issuetype" or field == "status" or field == "IssueParentAssociation" then
		local s, e = row:find(" -> ", 1, true)
		if s == nil or e == nil then
			return nil
		end

		local function side_values()
			local from_segment = row:sub(1, s - 1)
			local to_segment = row:sub(e + 1)

			local from_space = from_segment:find(" ", 1, true)
			local to_space = to_segment:find(" ", 1, true)

			local from_value = vim.trim(from_space and from_segment:sub(from_space + 1) or from_segment)
			local to_value = vim.trim(to_space and to_segment:sub(to_space + 1) or to_segment)

			return from_value, to_value
		end

		if field == "assignee" then
			local from_name, to_name = side_values()

			local from_hl = jira_ui_helper.person_hl(from_name)
			local to_hl = jira_ui_helper.person_hl(to_name)

			return {
				{ start_col = 0, end_col = s - 1, hl_group = from_hl },
				{ start_col = e, end_col = #row, hl_group = to_hl },
			}
		elseif field == "priority" then
			local from_priority, to_priority = side_values()

			local from_hl = jira_ui_helper.priority_hl(from_priority)
			local to_hl = jira_ui_helper.priority_hl(to_priority)

			return {
				{ start_col = 0, end_col = s - 1, hl_group = from_hl },
				{ start_col = e, end_col = #row, hl_group = to_hl },
			}
		elseif field == "issuetype" then
			local from_type, to_type = side_values()

			local from_hl = jira_ui_helper.issue_type_hl(from_type)
			local to_hl = jira_ui_helper.issue_type_hl(to_type)

			return {
				{ start_col = 0, end_col = s - 1, hl_group = from_hl },
				{ start_col = e, end_col = #row, hl_group = to_hl },
			}
		elseif field == "status" then
			local from_hl = jira_ui_helper.status_hl(history_item.from)
			local to_hl = jira_ui_helper.status_hl(history_item.to)

			return {
				{ start_col = 0, end_col = s - 1, hl_group = from_hl },
				{ start_col = e, end_col = #row, hl_group = to_hl },
			}
		elseif field == "IssueParentAssociation" then
			local from_value, to_value = side_values()
			local from_hl = jira_ui_helper.issue_hl(from_value)
			local to_hl = jira_ui_helper.issue_hl(to_value)

			return {
				{ start_col = 0, end_col = s - 1, hl_group = from_hl },
				{ start_col = e, end_col = #row, hl_group = to_hl },
			}
		end
	end

	return nil
end

---@param entries JiraIssueHistoryEntry[]|nil
---@return AtlasThreadedItem[]
local function to_thread_items(entries)
	local out = {}
	for _, entry in ipairs(entries or {}) do
		local author = ((entry or {}).author or {}).display_name or "Unknown"
		local timestamp = utils.relative_time_text((entry or {}).created)

		for _, item in ipairs((entry or {}).items or {}) do
			table.insert(out, {
				author = tostring(author),
				timestamp = tostring(timestamp),
				header_content = item_header(item),
				content = item_content(item),
				footer_items = item_footer(item),
				line_map = {
					history_entry = entry,
					history_item = item,
				},
			})
		end
	end

	return out
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
	local tabs_lines, tabs_spans = tabs.render("history", width, PADDING_X)
	utils.append_block(lines, spans, { lines = tabs_lines, highlights = tabs_spans })
	utils.append_block(lines, spans, { lines = { "" }, highlights = {} })

	--- Content
	if type(state.history_items) == "table" and #state.history_items > 0 then
		local items = to_thread_items(state.history_items)
		local item_lines, item_spans, item_map = threads.render(items, width, {
			padding_x = PADDING_X,
			header_content_hl = header_content_hl,
			content_hl = content_hl,
		})

		local offset = #lines
		utils.append_block(lines, spans, { lines = item_lines, highlights = item_spans })
		for lnum, entry in pairs(item_map or {}) do
			line_map[offset + lnum] = entry
		end
	elseif not state.is_loading then
		table.insert(lines, string.rep(" ", PADDING_X) .. "No history")
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #lines[#lines],
			hl_group = "AtlasTextMuted",
		})
	end

	if state.is_loading then
		local loading = string.rep(" ", PADDING_X) .. spinner.with_text("Loading history...")
		table.insert(lines, loading)
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #loading,
			hl_group = "AtlasTextMuted",
		})
	end

	line_map[1] = line_map[1] or { kind = "issue", issue = issue }
	line_map[#lines] = line_map[#lines] or { kind = "history" }
	state.line_map = line_map

	return lines, spans, state.line_map
end

return M
