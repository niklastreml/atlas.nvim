local M = {}

local state = require("atlas.bitbucket.panel.tabs.pr.files.state")
local panel_state = require("atlas.bitbucket.panel.state")
local header = require("atlas.bitbucket.panel.components.header")
local chips = require("atlas.bitbucket.panel.components.chips")
local tabs_component = require("atlas.bitbucket.panel.components.tabs")
local utils = require("atlas.utils")
local spinner = require("atlas.ui.components.spinner")

local CONTENT_PADDING = 1

---@param text string
---@return string
local function with_content_padding(text)
	return string.rep(" ", CONTENT_PADDING) .. tostring(text or "")
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
	local diffstat = state.diffstat
	local diff = state.diff

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
	local tab_lines, tab_spans = tabs_component.render_pr(panel_state.current_tab, { width = width, padding_x = 1 })
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

	-- Files content
	local diffstat_loading = diffstat == "loading"
	local diff_loading = diff == "loading"

	if diffstat_loading or diff_loading then
		local loading_line = spinner.with_text("Loading file changes...")
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

	local entries = (type(diffstat) == "table" and diffstat.entries) or {}
	local file_header = "Files"
	table.insert(lines, with_content_padding(file_header))
	table.insert(spans, {
		line = #lines - 1,
		start_col = CONTENT_PADDING,
		end_col = CONTENT_PADDING + #file_header,
		hl_group = "AtlasColumnHeader",
	})

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
	table.insert(lines, with_content_padding(stats_line))
	table.insert(spans, {
		line = stats_line_index,
		start_col = CONTENT_PADDING,
		end_col = CONTENT_PADDING + #added_text,
		hl_group = "AtlasTextPositive",
	})
	table.insert(spans, {
		line = stats_line_index,
		start_col = CONTENT_PADDING + #added_text + 2,
		end_col = CONTENT_PADDING + #stats_line,
		hl_group = "AtlasTextWarning",
	})
	table.insert(lines, "")

	if #entries == 0 then
		table.insert(lines, with_content_padding("No files changed."))
	else
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
			table.insert(lines, with_content_padding(file_line))
			table.insert(spans, {
				line = #lines - 1,
				start_col = CONTENT_PADDING,
				end_col = CONTENT_PADDING + 1,
				hl_group = hl_group,
			})
		end
	end
	table.insert(lines, "")

	local diff_text = (type(diff) == "table" and type(diff.text) == "string") and diff.text or ""
	if diff_text == "" then
		table.insert(lines, with_content_padding("No diff available."))
		state.line_map = line_map
		return lines, spans, line_map
	end

	local diff_lines = utils.sanitize_lines(diff_text)
	for _, line in ipairs(diff_lines) do
		table.insert(lines, with_content_padding(line))
		local idx = #lines - 1
		if line:match("^%+") and not line:match("^%+%+%+") then
			table.insert(spans, { line = idx, start_col = CONTENT_PADDING, end_col = CONTENT_PADDING + #line, hl_group = "AtlasTextPositive" })
		elseif line:match("^%-") and not line:match("^%-%-%-") then
			table.insert(spans, { line = idx, start_col = CONTENT_PADDING, end_col = CONTENT_PADDING + #line, hl_group = "AtlasTextWarning" })
		elseif line:match("^@@") then
			table.insert(spans, { line = idx, start_col = CONTENT_PADDING, end_col = CONTENT_PADDING + #line, hl_group = "AtlasTextMuted" })
		end
	end

	state.line_map = line_map
	return lines, spans, line_map
end

return M
