local M = {}

local utils = require("atlas.utils")
local icons = require("atlas.ui.icons")
local table_view = require("atlas.ui.components.table")
local spinner = require("atlas.ui.components.spinner")

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

---@param pr table|nil
---@param detail BitbucketPRDetail|"loading"|nil
---@param width integer|nil
---@return string[]
---@return table[]
function M.render(pr, detail, width)
	local lines = {}
	local spans = {}

	local description_text = ((pr or {}).rendered or {}).description
	description_text = (description_text or {}).raw or (pr or {}).description or ((pr or {}).summary or {}).raw or ""
	local description = utils.sanitize_lines(description_text)
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

return M
