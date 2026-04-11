local M = {}

local state = require("atlas.bitbucket.panel.tabs.pr.overview.state")
local pr_state = require("atlas.bitbucket.panel.tabs.pr.state")
local header = require("atlas.bitbucket.panel.components.header")
local chips = require("atlas.bitbucket.panel.components.chips")
local tabs = require("atlas.bitbucket.panel.components.tabs")
local pr_helper = require("atlas.bitbucket.panel.tabs.pr.helper")
local utils = require("atlas.utils")
local icons = require("atlas.ui.utils.icons")
local spinner = require("atlas.ui.components.spinner")

local CONTENT_PADDING = 1

---@param text string
---@return string
local function with_content_padding(text)
	return string.rep(" ", CONTENT_PADDING) .. tostring(text or "")
end

---@param lines string[]
---@param spans table[]
---@param text string
---@param hl_group string|nil
local function push(lines, spans, text, hl_group)
	table.insert(lines, with_content_padding(text))
	if hl_group then
		table.insert(spans, {
			line = #lines - 1,
			start_col = CONTENT_PADDING,
			end_col = CONTENT_PADDING + #text,
			hl_group = hl_group,
		})
	end
end

local table_view = require("atlas.ui.components.table_tree")

local STATUS_MAP = {
	added = { "+", "AtlasTextPositive" },
	removed = { "-", "AtlasLogError" },
	deleted = { "-", "AtlasLogError" },
	renamed = { "R", "AtlasLogWarn" },
}

local function diffstat_path(entry)
	local status = tostring(entry.status or ""):lower()
	local old = entry.old_file ~= nil and entry.old_file.path or ""
	local new = entry.new_file ~= nil and entry.new_file.path or ""

	if status == "renamed" and old ~= "" and new ~= "" then
		return old .. " → " .. new
	elseif status == "added" then
		return new ~= "" and new or old
	elseif status == "removed" or status == "deleted" then
		return old ~= "" and old or new
	end
	return (new ~= "" and new or old) ~= "" and (new ~= "" and new or old) or "(unknown file)"
end

local function render_diffstat(diffstat, width)
	local L, S = {}, {}
	local pad = CONTENT_PADDING

	if diffstat == "loading" or diffstat == nil then
		local hdr = "Files changed"
		table.insert(L, with_content_padding(hdr))
		table.insert(S, { line = #L - 1, start_col = pad, end_col = pad + #hdr, hl_group = "AtlasColumnHeader" })
		local msg = diffstat == "loading" and spinner.with_text("Loading file changes...") or "No file info available."
		table.insert(L, with_content_padding(msg))
		table.insert(S, { line = #L - 1, start_col = pad, end_col = pad + #msg, hl_group = "AtlasTextMuted" })
		return L, S
	end

	local entries = diffstat.entries or {}

	-- Header
	local hdr = string.format("Files changed (%d)", #entries)
	table.insert(L, with_content_padding(hdr))
	table.insert(S, { line = #L - 1, start_col = pad, end_col = pad + #hdr, hl_group = "AtlasColumnHeader" })

	if #entries == 0 then
		table.insert(L, with_content_padding("No files changed."))
		return L, S
	end

	local rows = {}
	for _, entry in ipairs(entries) do
		local status = tostring(entry.status or ""):lower()
		local m = STATUS_MAP[status] or { "~", "AtlasTextMuted" }
		table.insert(rows, {
			marker = m[1],
			marker_hl = m[2],
			path = diffstat_path(entry),
			added = string.format("+%d", tonumber(entry.lines_added) or 0),
			removed = string.format("-%d", tonumber(entry.lines_removed) or 0),
		})
	end

	local tbl_lines, _, tbl_spans = table_view.render({
		width = width,
		margin = pad,
		column_gap = 1,
		show_header = false,
		fill = true,
		columns = {
			{ key = "marker", can_grow = false, max_width = 1 },
			{ key = "path", can_grow = true, truncate_from = "start" },
			{ key = "added", can_grow = false, align = "center" },
			{ key = "removed", can_grow = false, align = "center" },
		},
		rows = rows,
		cell_hl = function(row, col)
			if col.key == "marker" then
				return row.marker_hl
			end
			if col.key == "path" then
				return "AtlasTextMuted"
			end
			if col.key == "added" then
				return "AtlasTextPositive"
			end
			if col.key == "removed" then
				return "AtlasLogError"
			end
		end,
	})

	utils.append_block(L, S, { lines = tbl_lines, highlights = tbl_spans })

	return L, S
end

---@param decision string
---@return string
local function decision_icon(decision)
	if decision == "approved" then
		return icons.bitbucket_icon("bitbucket.entity.success")
	end
	if decision == "changes_requested" then
		return icons.bitbucket_icon("bitbucket.entity.warning")
	end
	return icons.bitbucket_icon("bitbucket.entity.pending")
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

---@param status string
---@return string
local function status_hl(status)
	if status == "SUCCESSFUL" then
		return "AtlasBuildLinkSuccess"
	end
	if status == "FAILED" then
		return "AtlasBuildLinkFailed"
	end
	if status == "INPROGRESS" then
		return "AtlasBuildLinkInProgress"
	end
	if status == "STOPPED" then
		return "AtlasBuildLinkMuted"
	end
	return "AtlasBuildLinkMuted"
end

---@param width integer
---@return string[] lines
---@return table[] spans
---@return table|nil line_map
function M.render(width)
	local lines = {}
	local spans = {}
	local line_map = {}

	local pr = state.pr
	local detail = state.detail
	local diffstat = state.diffstat

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
	local tab_lines, tab_spans = tabs.render_pr(pr_state.tab, { width = width, padding_x = 1 })
	utils.append_block(lines, spans, { lines = tab_lines, highlights = tab_spans })
	table.insert(lines, "")

	-- Reviewers
	local is_loading = detail == "loading"
	local decisions = {}
	if not is_loading and detail then
		for _, p in ipairs(detail.participants or {}) do
			if tostring(p.role or "") == "REVIEWER" then
				table.insert(decisions, {
					name = p.name,
					nickname = p.nickname,
					decision = p.state or "pending",
				})
			end
		end

		if #decisions == 0 then
			for _, r in ipairs(detail.reviewers or {}) do
				table.insert(decisions, {
					name = r.name,
					nickname = r.nickname,
					decision = "pending",
				})
			end
		end
	end

	local approvals = (not is_loading and detail and detail.approvals_count) or 0
	local reviewers_line = is_loading and "Reviewers (...)" or string.format("Reviewers (%d/%d)", approvals, #decisions)
	table.insert(lines, with_content_padding(reviewers_line))
	table.insert(spans, {
		line = #lines - 1,
		start_col = CONTENT_PADDING,
		end_col = CONTENT_PADDING + #reviewers_line,
		hl_group = "AtlasColumnHeader",
	})
	local count_text = is_loading and "(...)" or string.format("(%d/%d)", approvals, #decisions)
	local count_start = #reviewers_line - #count_text
	table.insert(spans, {
		line = #lines - 1,
		start_col = CONTENT_PADDING + count_start,
		end_col = CONTENT_PADDING + #reviewers_line,
		hl_group = "AtlasTextMuted",
	})

	if is_loading then
		local loading_line = spinner.with_text("Loading reviewers...")
		push(lines, spans, loading_line, "AtlasTextMuted")
	elseif #decisions == 0 then
		push(lines, spans, "no reviewers yet", nil)
	else
		local groups = { "approved", "changes_requested", "pending" }
		local grouped = { approved = {}, changes_requested = {}, pending = {} }

		for _, d in ipairs(decisions) do
			local status = tostring(d.decision or "pending")
			if grouped[status] == nil then
				status = "pending"
			end
			local name = (d.name and d.name ~= "") and d.name
				or (d.nickname and d.nickname ~= "") and d.nickname
				or "Unknown"
			table.insert(grouped[status], name)
		end

		for _, status in ipairs(groups) do
			local names = grouped[status]
			if #names > 0 then
				table.sort(names)
				local icon = decision_icon(status)
				local label = table.concat(names, ", ")
				local icon_prefix = icon .. " "
				local icon_prefix_width = vim.api.nvim_strwidth(icon_prefix)
				local content_width = math.max(10, width - (CONTENT_PADDING * 2))
				local label_width = math.max(1, content_width - icon_prefix_width)
				local wrapped = utils.wrap_line(label, label_width)

				local line_text = icon_prefix .. wrapped[1]
				table.insert(lines, with_content_padding(line_text))
				table.insert(spans, {
					line = #lines - 1,
					start_col = CONTENT_PADDING,
					end_col = CONTENT_PADDING + #icon,
					hl_group = decision_hl(status),
				})

				local continuation_prefix = string.rep(" ", icon_prefix_width)
				for i = 2, #wrapped do
					table.insert(lines, with_content_padding(continuation_prefix .. wrapped[i]))
				end
			end
		end
	end
	table.insert(lines, "")

	local content_width = math.max(10, width - (CONTENT_PADDING * 2))

	-- Builds (pipelines)
	local statuses = pr_state.statuses
	local checks_header = "Builds"
	table.insert(lines, with_content_padding(checks_header))
	table.insert(spans, {
		line = #lines - 1,
		start_col = CONTENT_PADDING,
		end_col = CONTENT_PADDING + #checks_header,
		hl_group = "AtlasColumnHeader",
	})

	if statuses == "loading" then
		push(lines, spans, spinner.with_text("Loading builds..."), "AtlasTextMuted")
	elseif type(statuses) ~= "table" or type(statuses.entries) ~= "table" or #statuses.entries == 0 then
		push(lines, spans, "No builds found", "AtlasTextMuted")
	else
		for _, entry in ipairs(statuses.entries) do
			local status = tostring(entry.state or "UNKNOWN")
			local status_label = pr_helper.statuses.label(status)
			local icon = icons.bitbucket_icon("bitbucket.status." .. status)
			local name = tostring(entry.name or "")
			if name == "" then
				name = tostring(entry.key or "")
			end
			if name == "" then
				name = "Check"
			end

			local text = string.format("%s %s (%s)", icon, name, status_label)
			local wrapped = utils.wrap_line(text, content_width)
			for i, chunk in ipairs(wrapped) do
				table.insert(lines, with_content_padding(chunk))
				line_map[#lines] = {
					kind = "build",
					build = entry,
					url = tostring(entry.url or ""),
				}
				if i == 1 then
					table.insert(spans, {
						line = #lines - 1,
						start_col = CONTENT_PADDING,
						end_col = CONTENT_PADDING + #chunk,
						hl_group = status_hl(status),
					})
				elseif tostring(entry.url or "") ~= "" then
					table.insert(spans, {
						line = #lines - 1,
						start_col = CONTENT_PADDING,
						end_col = CONTENT_PADDING + #chunk,
						hl_group = "AtlasBuildLinkMuted",
					})
				end
			end
		end
	end
	table.insert(lines, "")

	-- Description
	local description_text = pr.description or ""
	local description = utils.sanitize_lines(description_text)
	local description_header = "Description"
	table.insert(lines, with_content_padding(description_header))
	table.insert(spans, {
		line = #lines - 1,
		start_col = CONTENT_PADDING,
		end_col = CONTENT_PADDING + #description_header,
		hl_group = "AtlasColumnHeader",
	})
	for _, line in ipairs(description) do
		local wrapped = utils.wrap_line(line, content_width)
		for _, chunk in ipairs(wrapped) do
			table.insert(lines, with_content_padding(chunk))
		end
	end

	-- Diffstat
	local ds_lines, ds_spans = render_diffstat(diffstat, width)
	utils.append_block(lines, spans, { lines = ds_lines, highlights = ds_spans })

	state.line_map = line_map
	return lines, spans, line_map
end

return M
