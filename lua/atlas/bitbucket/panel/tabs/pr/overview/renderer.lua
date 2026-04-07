local M = {}

local state = require("atlas.bitbucket.panel.tabs.pr.overview.state")
local panel_state = require("atlas.bitbucket.panel.state")
local header = require("atlas.bitbucket.panel.components.header")
local chips = require("atlas.bitbucket.panel.components.chips")
local tabs = require("atlas.bitbucket.panel.components.tabs")
local utils = require("atlas.utils")
local icons = require("atlas.ui.icons")
local table_view = require("atlas.ui.components.table_tree")
local spinner = require("atlas.ui.components.spinner")

local CONTENT_PADDING = 1

---@param text string
---@return string
local function with_content_padding(text)
	return string.rep(" ", CONTENT_PADDING) .. tostring(text or "")
end

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

---@param decision string
---@return integer
local function decision_rank(decision)
	if decision == "approved" then
		return 1
	end
	if decision == "changes_requested" then
		return 2
	end
	return 3
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

	if pr == nil then
		return { "", "  No PR selected..." }, {}, nil
	end

	-- Header
	local header_lines, header_spans = header.render(pr, width)
	for _, line in ipairs(header_lines) do
		table.insert(lines, line)
	end
	for _, span in ipairs(header_spans) do
		table.insert(spans, span)
	end

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
	local tab_lines, tab_spans = tabs.render_pr(panel_state.current_tab, { width = width, padding_x = 1 })
	local tab_base = #lines
	for _, line in ipairs(tab_lines) do
		table.insert(lines, line)
	end
	for _, span in ipairs(tab_spans) do
		table.insert(spans, {
			line = tab_base + span.line,
			start_col = span.start_col,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
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
		table.insert(lines, with_content_padding(line))
	end
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
		table.insert(lines, with_content_padding(loading_line))
		table.insert(spans, {
			line = #lines - 1,
			start_col = CONTENT_PADDING,
			end_col = CONTENT_PADDING + #loading_line,
			hl_group = "AtlasTextMuted",
		})
		state.line_map = line_map
		return lines, spans, line_map
	end

	if #decisions == 0 then
		table.insert(lines, with_content_padding("no reviewers yet"))
		state.line_map = line_map
		return lines, spans, line_map
	end

	local sorted_decisions = {}
	for _, d in ipairs(decisions) do
		table.insert(sorted_decisions, d)
	end
	table.sort(sorted_decisions, function(a, b)
		local ar = decision_rank(tostring(a.decision or ""))
		local br = decision_rank(tostring(b.decision or ""))
		if ar ~= br then
			return ar < br
		end

		local an = tostring(a.name or a.nickname or "")
		local bn = tostring(b.name or b.nickname or "")
		return an < bn
	end)

	local rows = {}
	for _, d in ipairs(sorted_decisions) do
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
		table.insert(lines, with_content_padding(line))
	end
	for _, span in ipairs(table_spans or {}) do
		table.insert(spans, {
			line = base + span.line,
			start_col = CONTENT_PADDING + span.start_col,
			end_col = CONTENT_PADDING + span.end_col,
			hl_group = span.hl_group,
		})
	end

	state.line_map = line_map
	return lines, spans, line_map
end

return M
