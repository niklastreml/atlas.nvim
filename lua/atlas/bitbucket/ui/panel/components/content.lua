local M = {}

local utils = require("atlas.utils")
local icons = require("atlas.ui.icons")
local table_view = require("atlas.ui.components.table")
local spinner = require("atlas.ui.components.spinner")
local highlights = require("atlas.ui.highlights")
local comments_component = require("atlas.bitbucket.ui.panel.components.tabs.comments")

---@param decision string
---@return string
local function decision_icon(decision)
	if decision == "approved" then
		return icons.entity("success")
	end
	if decision == "changes_requested" then
		return icons.entity("warning")
	end
	return icons.entity("pending")
end

---@param decision string
---@return string
local function decision_hl(decision)
	if decision == "approved" then
		return "AtlasTextPositive"
	end
	if decision == "changes_requested" then
		return "AtlasTextWarning"
	end
	return "AtlasTextMuted"
end

---@param pr table|nil
---@param detail BitbucketPRDetail|"loading"|nil
---@param width integer|nil
---@return string[]
---@return table[]
local function overview_lines(pr, detail, width)
	local lines = {}
	local spans = {}

	--- Description
	local description_text = ((pr or {}).rendered or {}).description
	description_text = (description_text or {}).raw or (pr or {}).description or ((pr or {}).summary or {}).raw or ""
	local description = utils.sanitize_markdown_lines(description_text)
	local description_header = "Description"
	table.insert(lines, description_header)
	table.insert(spans, {
		line = #lines - 1,
		start_col = 0,
		end_col = #description_header,
		hl_group = "AtlasSectionHeader",
	})
	for _, line in ipairs(description) do
		table.insert(lines, line)
	end
	table.insert(lines, "")

	--- Reviewers
	local is_loading = detail == "loading"
	local decisions = (not is_loading and detail and detail.decisions) or {}
	local approvals = (not is_loading and detail and detail.approvals_count) or 0
	local reviewers_line = is_loading and "Reviewers (...)" or string.format("Reviewers (%d/%d)", approvals, #decisions)
	table.insert(lines, reviewers_line)
	table.insert(spans, {
		line = #lines - 1,
		start_col = 0,
		end_col = #reviewers_line,
		hl_group = "AtlasSectionHeader",
	})
	local count_text = is_loading and "(...)" or string.format("(%d/%d)", approvals, #decisions)
	local count_start = #reviewers_line - #count_text
	table.insert(spans, {
		line = #lines - 1,
		start_col = count_start,
		end_col = #reviewers_line,
		hl_group = "AtlasTextMuted",
	})

	if is_loading then
		local loading_line = spinner.with_text("Loading reviewers...")
		table.insert(lines, loading_line)
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #loading_line,
			hl_group = "AtlasTextMuted",
		})
		return lines, spans
	end

	if #decisions == 0 then
		table.insert(lines, "no reviewers yet")
		return lines, spans
	end

	local rows = {}
	for _, d in ipairs(decisions) do
		local name = d.name
		if name == nil or name == "" then
			name = (d.nickname and d.nickname ~= "") and d.nickname or "Unknown"
		end
		table.insert(rows, {
			status = decision_icon(d.decision),
			name = name,
			decision = d.decision,
		})
	end

	local table_lines, _, table_spans = table_view.render({
		width = width or 60,
		margin = 0,
		column_gap = 1,
		show_header = false,
		fill = false,
		columns = {
			{ key = "status", name = "", width = 2, can_grow = false },
			{ key = "name", name = "", min_width = 20, can_grow = false },
		},
		rows = rows,
		cell_hl = function(row, col)
			if col.key == "status" then
				return decision_hl(row.decision)
			end
			return nil
		end,
	})

	local base = #lines
	for _, line in ipairs(table_lines) do
		table.insert(lines, line)
	end
	for _, span in ipairs(table_spans or {}) do
		table.insert(spans, {
			line = base + span.line,
			start_col = span.start_col,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end

	return lines, spans
end

---@param commits BitbucketPRCommits|"loading"|nil
---@param width integer|nil
---@return string[]
---@return table[]
local function commits_lines(commits, width)
	local lines = {}
	local spans = {}

	if commits == "loading" then
		local loading_line = spinner.with_text("Loading commits...")
		table.insert(lines, loading_line)
		table.insert(spans, {
			line = 0,
			start_col = 0,
			end_col = #loading_line,
			hl_group = "AtlasTextMuted",
		})
		return lines, spans
	end

	local entries = (type(commits) == "table" and commits.entries) or {}
	if type(entries) ~= "table" or #entries == 0 then
		return { "No commits yet." }, spans
	end

	local rows = {}
	for _, c in ipairs(entries) do
		local msg = tostring(c.message or ""):gsub("\r\n", "\n")
		msg = msg:match("([^\n]+)") or msg
		local author = (c.author_nickname ~= "" and c.author_nickname) or c.author_name or "Unknown"
		table.insert(rows, {
			icon = icons.entity("commit"),
			hash = c.short_hash or "",
			message = msg,
			author = author,
			date = utils.relative_time(c.date),
		})
	end

	local table_lines, _, table_spans = table_view.render({
		width = width,
		margin = 0,
		column_gap = 1,
		show_header = false,
		fill = true,
		columns = {
			{ key = "icon", name = "", width = 2, can_grow = false },
			{ key = "hash", name = "", width = 12, can_grow = false },
			{ key = "message", name = "", min_width = 24, can_grow = true },
			{ key = "author", name = "", can_grow = false },
			{ key = "date", name = "", width = 6, can_grow = false },
		},
		rows = rows,
		cell_hl = function(row, col)
			if col.key == "icon" then
				return "AtlasTextPositive"
			end
			if col.key == "hash" or col.key == "date" then
				return "AtlasTextMuted"
			end
			if col.key == "author" then
				return highlights.dynamic_for(row.author)
			end
			return nil
		end,
	})

	for _, line in ipairs(table_lines) do
		table.insert(lines, line)
	end
	for _, span in ipairs(table_spans or {}) do
		table.insert(spans, span)
	end

	return lines, spans
end

---@param activity BitbucketPRActivity|"loading"|nil
---@param width integer|nil
---@return string[]
---@return table[]
local function activity_lines(activity, width)
	local lines = {}
	local spans = {}

	if activity == "loading" then
		local loading_line = spinner.with_text("Loading activity...")
		table.insert(lines, loading_line)
		table.insert(spans, {
			line = 0,
			start_col = 0,
			end_col = #loading_line,
			hl_group = "AtlasTextMuted",
		})
		return lines, spans
	end

	local entries = (type(activity) == "table" and activity.entries) or {}
	if type(entries) ~= "table" or #entries == 0 then
		return { "No activity yet." }, spans
	end

	local function first_line(text)
		local raw = tostring(text or ""):gsub("\r\n", "\n")
		return raw:match("([^\n]+)") or raw
	end

	local function actor_name(actor)
		if type(actor) ~= "table" then
			return "Unknown"
		end
		if type(actor.nickname) == "string" and actor.nickname ~= "" then
			return actor.nickname
		end
		if type(actor.name) == "string" and actor.name ~= "" then
			return actor.name
		end
		return "Unknown"
	end

	local function update_detail(entry)
		local changes = type(entry.changes) == "table" and entry.changes or {}
		local keys = {}
		for key, _ in pairs(changes) do
			table.insert(keys, tostring(key))
		end
		table.sort(keys)
		if #keys > 0 then
			return "changes: " .. table.concat(keys, ", ")
		end

		local source_branch = tostring(entry.source_branch or "")
		local target_branch = tostring(entry.target_branch or "")
		if source_branch ~= "" and target_branch ~= "" then
			return string.format("%s -> %s", source_branch, target_branch)
		end

		return "pull request updated"
	end

	local rows = {}
	for _, e in ipairs(entries) do
		local kind = tostring(e.kind or "")
		local actor = actor_name(e.actor)
		local action = "updated"
		local icon = icons.entity("activity")
		local detail = ""

		if kind == "approval" then
			action = "approved"
			icon = icons.entity("success")
			detail = "approval"
		elseif kind == "comment" then
			action = "commented"
			icon = icons.entity("comment")
			detail = first_line(e.content_raw)
		elseif kind == "update" then
			action = "updated"
			icon = icons.entity("activity")
			detail = update_detail(e)
		end

		table.insert(rows, {
			kind = "event",
			event_kind = kind,
			icon = icon,
			event = action,
			actor = actor,
			date = utils.relative_time(e.date),
		})

		table.insert(rows, {
			kind = "meta",
			event_kind = kind,
			icon = "",
			event = detail,
			actor = "",
			date = "",
			separator = true,
		})
	end

	local table_lines, _, table_spans = table_view.render({
		width = width,
		margin = 0,
		column_gap = 1,
		show_header = false,
		fill = true,
		columns = {
			{ key = "icon", name = "", width = 2, can_grow = false },
			{ key = "event", name = "", min_width = 26, can_grow = true },
			{ key = "actor", name = "", min_width = 12, can_grow = false },
			{ key = "date", name = "", width = 8, can_grow = false },
		},
		rows = rows,
		cell_hl = function(row, col)
			if col.key == "icon" then
				if row.kind ~= "event" then
					return nil
				end
				if row.event_kind == "approval" then
					return "AtlasTextPositive"
				end
				if row.event_kind == "comment" then
					return "AtlasTextMuted"
				end
				return "AtlasTextWarning"
			end
			if row.kind == "meta" and col.key == "event" then
				return "AtlasTextMuted"
			end
			if col.key == "date" then
				return "AtlasTextMuted"
			end
			if row.kind == "event" and col.key == "actor" then
				return highlights.dynamic_for(row.actor)
			end
			return nil
		end,
	})

	for _, line in ipairs(table_lines) do
		table.insert(lines, line)
	end
	for _, span in ipairs(table_spans or {}) do
		table.insert(spans, span)
	end

	return lines, spans
end

---@param diffstat BitbucketPRDiffstat|"loading"|nil
---@param diff BitbucketPRDiff|"loading"|nil
---@param width integer|nil
---@return string[]
---@return table[]
local function files_lines(diffstat, diff, width)
	local lines = {}
	local spans = {}

	local diffstat_loading = diffstat == "loading"
	local diff_loading = diff == "loading"

	if diffstat_loading or diff_loading then
		local loading_line = spinner.with_text("Loading file changes...")
		table.insert(lines, loading_line)
		table.insert(spans, {
			line = 0,
			start_col = 0,
			end_col = #loading_line,
			hl_group = "AtlasTextMuted",
		})
		return lines, spans
	end

	local entries = (type(diffstat) == "table" and diffstat.entries) or {}
	local file_header = "Files"
	table.insert(lines, file_header)
	table.insert(spans, {
		line = #lines - 1,
		start_col = 0,
		end_col = #file_header,
		hl_group = "AtlasSectionHeader",
	})

	if #entries == 0 then
		table.insert(lines, "No files changed.")
		table.insert(lines, "")
	else
		---FIX: Horrible and probably wont always work...
		for _, entry in ipairs(entries) do
			local status = tostring(entry.status or ""):lower()
			local old_path = (type(entry.old_file) == "table" and tostring(entry.old_file.path or "")) or ""
			local new_path = (type(entry.new_file) == "table" and tostring(entry.new_file.path or "")) or ""

			local marker = "~"
			local hl_group = "AtlasTextMuted"
			local path = (new_path ~= "" and new_path) or old_path

			if status == "added" then
				marker = "+"
				hl_group = "AtlasTextPositive"
				path = (new_path ~= "" and new_path) or old_path
			elseif status == "removed" or status == "deleted" then
				marker = "-"
				hl_group = "AtlasTextWarning"
				path = (old_path ~= "" and old_path) or new_path
			elseif status == "renamed" then
				marker = "R"
				hl_group = "AtlasTextMuted"
				if old_path ~= "" and new_path ~= "" then
					path = string.format("%s -> %s", old_path, new_path)
				end
			end

			if path == "" then
				path = "(unknown file)"
			end

			local file_line = string.format("%s %s", marker, path)
			table.insert(lines, file_line)
			table.insert(spans, {
				line = #lines - 1,
				start_col = 0,
				end_col = 1,
				hl_group = hl_group,
			})
		end
		table.insert(lines, "")
	end

	local added = 0
	local removed = 0
	for _, e in ipairs(entries) do
		added = added + (tonumber(e.lines_added) or 0)
		removed = removed + (tonumber(e.lines_removed) or 0)
	end

	local added_text = string.format("+%d added", added)
	local removed_text = string.format("-%d removed", removed)
	local stats_line = string.format("%s  %s", added_text, removed_text)
	local stats_line_index = #lines
	table.insert(lines, stats_line)
	table.insert(spans, {
		line = stats_line_index,
		start_col = 0,
		end_col = #added_text,
		hl_group = "AtlasTextPositive",
	})
	table.insert(spans, {
		line = stats_line_index,
		start_col = #added_text + 2,
		end_col = #stats_line,
		hl_group = "AtlasTextWarning",
	})
	table.insert(lines, "")

	local diff_text = (type(diff) == "table" and type(diff.text) == "string") and diff.text or ""
	if diff_text == "" then
		table.insert(lines, "No diff available.")
		return lines, spans
	end

	local diff_lines = utils.sanitize_markdown_lines(diff_text)
	for _, line in ipairs(diff_lines) do
		table.insert(lines, line)
		local idx = #lines - 1
		if line:match("^%+") and not line:match("^%+%+%+") then
			table.insert(spans, { line = idx, start_col = 0, end_col = #line, hl_group = "AtlasTextPositive" })
		elseif line:match("^%-") and not line:match("^%-%-%-") then
			table.insert(spans, { line = idx, start_col = 0, end_col = #line, hl_group = "AtlasTextWarning" })
		elseif line:match("^@@") then
			table.insert(spans, { line = idx, start_col = 0, end_col = #line, hl_group = "AtlasTextMuted" })
		end
	end

	return lines, spans
end

---@param tab "overview"|"activity"|"comments"|"commits"|"files"
---@param pr table|nil
---@param detail BitbucketPRDetail|"loading"|nil
---@param activity BitbucketPRActivity|"loading"|nil
---@param comments BitbucketPRComments|"loading"|nil
---@param commits BitbucketPRCommits|"loading"|nil
---@param diffstat BitbucketPRDiffstat|"loading"|nil
---@param diff BitbucketPRDiff|"loading"|nil
---@param width integer|nil
---@return string[] lines
---@return table[] spans
function M.render(tab, pr, detail, activity, comments, commits, diffstat, diff, width)
	if tab == "overview" then
		return overview_lines(pr, detail, width)
	end
	if tab == "activity" then
		return activity_lines(activity, width)
	end
	if tab == "comments" then
		return comments_component.render(comments, width)
	end
	if tab == "commits" then
		return commits_lines(commits, width)
	end
	if tab == "files" then
		return files_lines(diffstat, diff, width)
	end

	return { "You shouldn’t be here..." }, {}
end
return M
