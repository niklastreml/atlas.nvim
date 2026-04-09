local M = {}

local state = require("atlas.bitbucket.panel.tabs.pr.overview.state")
local panel_state = require("atlas.bitbucket.panel.state")
local header = require("atlas.bitbucket.panel.components.header")
local chips = require("atlas.bitbucket.panel.components.chips")
local tabs = require("atlas.bitbucket.panel.components.tabs")
local utils = require("atlas.utils")
local icons = require("atlas.ui.icons")
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
				local line_text = icon .. " " .. label
				table.insert(lines, with_content_padding(line_text))
				table.insert(spans, {
					line = #lines - 1,
					start_col = CONTENT_PADDING,
					end_col = CONTENT_PADDING + #icon,
					hl_group = decision_hl(status),
				})
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
		table.insert(lines, with_content_padding(line))
	end
	table.insert(lines, "")

	-- Diffstat
	local diffstat_header = "Files"
	table.insert(lines, with_content_padding(diffstat_header))
	table.insert(spans, {
		line = #lines - 1,
		start_col = CONTENT_PADDING,
		end_col = CONTENT_PADDING + #diffstat_header,
		hl_group = "AtlasColumnHeader",
	})

	if diffstat == "loading" then
		local loading_line = spinner.with_text("Loading file changes...")
		push(lines, spans, loading_line, "AtlasTextMuted")
	elseif diffstat == nil then
		push(lines, spans, "No file info available.", nil)
	else
		local entries = diffstat.entries

		local added_count, removed_count = 0, 0
		for _, e in ipairs(entries) do
			added_count = added_count + (tonumber(e.lines_added) or 0)
			removed_count = removed_count + (tonumber(e.lines_removed) or 0)
		end

		local added_text = string.format("+%d added", added_count)
		local removed_text = string.format("-%d removed", removed_count)
		local stats_line = added_text .. "  " .. removed_text
		local stats_idx = #lines
		table.insert(lines, with_content_padding(stats_line))
		table.insert(spans, {
			line = stats_idx,
			start_col = CONTENT_PADDING,
			end_col = CONTENT_PADDING + #added_text,
			hl_group = "AtlasTextPositive",
		})
		table.insert(spans, {
			line = stats_idx,
			start_col = CONTENT_PADDING + #added_text + 2,
			end_col = CONTENT_PADDING + #stats_line,
			hl_group = "AtlasTextWarning",
		})
		table.insert(lines, "")

		if #entries == 0 then
			push(lines, spans, "No files changed.", nil)
		else
			for _, entry in ipairs(entries) do
				local status = tostring(entry.status or ""):lower()
				local old_path = entry.old_file ~= nil and entry.old_file.path or ""
				local new_path = entry.new_file ~= nil and entry.new_file.path or ""

				local marker, hl, path = "~", "AtlasTextMuted", (new_path ~= "" and new_path) or old_path
				if status == "added" then
					marker, hl, path = "+", "AtlasTextPositive", (new_path ~= "" and new_path) or old_path
				elseif status == "removed" or status == "deleted" then
					marker, hl, path = "-", "AtlasTextWarning", (old_path ~= "" and old_path) or new_path
				elseif status == "renamed" then
					marker, hl = "R", "AtlasTextMuted"
					if old_path ~= "" and new_path ~= "" then
						path = old_path .. " -> " .. new_path
					end
				end

				local file_line = marker .. " " .. (path ~= "" and path or "(unknown file)")
				table.insert(lines, with_content_padding(file_line))
				table.insert(
					spans,
					{ line = #lines - 1, start_col = CONTENT_PADDING, end_col = CONTENT_PADDING + 1, hl_group = hl }
				)
			end
		end
	end

	state.line_map = line_map
	return lines, spans, line_map
end

return M
