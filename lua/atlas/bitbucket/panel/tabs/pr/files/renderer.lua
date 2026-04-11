local M = {}

local state = require("atlas.bitbucket.panel.tabs.pr.files.state")
local pr_state = require("atlas.bitbucket.panel.tabs.pr.state")
local header = require("atlas.bitbucket.panel.components.header")
local chips = require("atlas.bitbucket.panel.components.chips")
local tabs_component = require("atlas.bitbucket.panel.components.tabs")
local spinner = require("atlas.ui.components.spinner")
local utils = require("atlas.utils")

local CONTENT_PADDING = 1

---@param text string
---@return string
local function pad(text)
	return string.rep(" ", CONTENT_PADDING) .. tostring(text or "")
end

---@param lines string[]
---@param spans table[]
---@param text string
---@param hl_group string|nil
local function push(lines, spans, text, hl_group)
	table.insert(lines, pad(text))
	if hl_group then
		table.insert(spans, {
			line = #lines - 1,
			start_col = CONTENT_PADDING,
			end_col = CONTENT_PADDING + #text,
			hl_group = hl_group,
		})
	end
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
	local diff = state.diff

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
	local tab_lines, tab_spans = tabs_component.render_pr(pr_state.tab, { width = width, padding_x = 1 })
	utils.append_block(lines, spans, { lines = tab_lines, highlights = tab_spans })
	table.insert(lines, "")

	-- Loading state
	if diff == "loading" then
		local loading_line = spinner.with_text("Loading file changes...")
		push(lines, spans, loading_line, "AtlasTextMuted")
		state.line_map = line_map
		return lines, spans, line_map
	end

	-- Diff hunks (structured data from diff_parser)
	local files = type(diff) == "table" and diff or {}
	if #files == 0 then
		push(lines, spans, "No diff available.", nil)
		state.line_map = line_map
		return lines, spans, line_map
	end

	local hunk_counter = 0

	for _, file in ipairs(files) do
		-- File path separator
		local path_label = file.path
		if file.status == "renamed" and file.old_path then
			path_label = file.old_path .. " -> " .. file.path
		end
		push(lines, spans, path_label, "AtlasColumnHeader")

		for _, hunk in ipairs(file.hunks) do
			hunk_counter = hunk_counter + 1
			local hunk_idx = hunk_counter
			local is_collapsed = state.collapsed_hunks[hunk_idx] == true
			local body_count = #hunk.lines

			-- @@ header line
			local display_header = is_collapsed and (hunk.header .. "  [+" .. body_count .. " lines]") or hunk.header
			table.insert(lines, pad(display_header))
			local buf_line = #lines
			table.insert(spans, {
				line = buf_line - 1,
				start_col = CONTENT_PADDING,
				end_col = CONTENT_PADDING + #display_header,
				hl_group = "AtlasTextMuted",
			})
			line_map[buf_line] = { type = "hunk_header", hunk_idx = hunk_idx }

			-- Body lines
			if not is_collapsed then
				for _, dl in ipairs(hunk.lines) do
					local hl = nil
					if dl.kind == "add" then
						hl = "AtlasTextPositive"
					elseif dl.kind == "remove" then
						hl = "AtlasTextWarning"
					elseif dl.kind == "meta" then
						hl = "AtlasTextMuted"
					end
					push(lines, spans, dl.text, hl)
				end
			end
		end

		table.insert(lines, "")
	end

	state.line_map = line_map
	return lines, spans, line_map
end

return M
