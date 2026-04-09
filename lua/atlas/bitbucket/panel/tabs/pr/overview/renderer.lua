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

---@param diffstat BitbucketPRDiffstat|"loading"|nil
---@param width integer
---@return string[] lines
---@return table[] spans
local function render_diffstat(diffstat, width)
	local out_lines = {}
	local out_spans = {}
	local pad = CONTENT_PADDING
	local inner_w = math.max(8, width - (pad * 2))

	if diffstat == "loading" then
		local section_header = "Files changes"
		table.insert(out_lines, with_content_padding(section_header))
		table.insert(out_spans, {
			line = #out_lines - 1,
			start_col = pad,
			end_col = pad + #section_header,
			hl_group = "AtlasColumnHeader",
		})
		local loading_line = spinner.with_text("Loading file changes...")
		table.insert(out_lines, with_content_padding(loading_line))
		table.insert(out_spans, {
			line = #out_lines - 1,
			start_col = pad,
			end_col = pad + #loading_line,
			hl_group = "AtlasTextMuted",
		})
		return out_lines, out_spans
	end

	if diffstat == nil then
		local section_header = "Files changes"
		table.insert(out_lines, with_content_padding(section_header))
		table.insert(out_spans, {
			line = #out_lines - 1,
			start_col = pad,
			end_col = pad + #section_header,
			hl_group = "AtlasColumnHeader",
		})
		table.insert(out_lines, with_content_padding("No file info available."))
		return out_lines, out_spans
	end

	local entries = diffstat.entries or {}

	local total_added, total_removed = 0, 0
	for _, e in ipairs(entries) do
		total_added = total_added + (tonumber(e.lines_added) or 0)
		total_removed = total_removed + (tonumber(e.lines_removed) or 0)
	end

	local left = string.format("Files changed (%d)", #entries)
	local right_add = string.format("+%d", total_added)
	local right_rm = string.format("-%d", total_removed)
	local right = right_add .. "  " .. right_rm

	local left_dw = vim.api.nvim_strwidth(left)
	local right_dw = vim.api.nvim_strwidth(right)
	local gap = math.max(2, inner_w - left_dw - right_dw)
	local header_line = string.rep(" ", pad) .. left .. string.rep(" ", gap) .. right

	table.insert(out_lines, header_line)

	table.insert(out_spans, {
		line = #out_lines - 1,
		start_col = pad,
		end_col = pad + #left,
		hl_group = "AtlasColumnHeader",
	})

	local paren_text = string.format("(%d)", #entries)
	local paren_start = pad + #left - #paren_text
	table.insert(out_spans, {
		line = #out_lines - 1,
		start_col = paren_start,
		end_col = pad + #left,
		hl_group = "AtlasTextMuted",
	})

	local right_start = #header_line - #right
	table.insert(out_spans, {
		line = #out_lines - 1,
		start_col = right_start,
		end_col = right_start + #right_add,
		hl_group = "AtlasTextPositive",
	})
	local rm_start = right_start + #right_add + 2
	table.insert(out_spans, {
		line = #out_lines - 1,
		start_col = rm_start,
		end_col = rm_start + #right_rm,
		hl_group = "AtlasLogError",
	})

	if #entries == 0 then
		table.insert(out_lines, with_content_padding("No files changed."))
		return out_lines, out_spans
	end

	for _, entry in ipairs(entries) do
		local status = tostring(entry.status or ""):lower()
		local old_path = entry.old_file ~= nil and entry.old_file.path or ""
		local new_path = entry.new_file ~= nil and entry.new_file.path or ""

		local marker, marker_hl, path
		if status == "added" then
			marker, marker_hl = "+", "AtlasTextPositive"
			path = (new_path ~= "" and new_path) or old_path
		elseif status == "removed" or status == "deleted" then
			marker, marker_hl = "-", "AtlasLogError"
			path = (old_path ~= "" and old_path) or new_path
		elseif status == "renamed" then
			marker, marker_hl = "R", "AtlasLogWarn"
			if old_path ~= "" and new_path ~= "" then
				path = old_path .. " → " .. new_path
			else
				path = (new_path ~= "" and new_path) or old_path
			end
		else
			marker, marker_hl = "~", "AtlasTextMuted"
			path = (new_path ~= "" and new_path) or old_path
		end
		if path == "" then
			path = "(unknown file)"
		end

		-- Split path into dir + filename for styling
		local dir, name = path:match("^(.+/)([^/]+)$")
		if dir == nil then
			dir = ""
			name = path
		end

		-- Per-file stats
		local file_add = string.format("+%d", tonumber(entry.lines_added) or 0)
		local file_rm = string.format("-%d", tonumber(entry.lines_removed) or 0)
		local file_stats = file_add .. "  " .. file_rm

		-- Build: pad + marker + " " + dir + name + gap + file_stats
		local left_part = marker .. " " .. dir .. name
		local left_part_dw = vim.api.nvim_strwidth(left_part)
		local stats_dw = vim.api.nvim_strwidth(file_stats)
		local file_gap = math.max(2, inner_w - left_part_dw - stats_dw)
		local file_line = string.rep(" ", pad) .. left_part .. string.rep(" ", file_gap) .. file_stats

		table.insert(out_lines, file_line)
		local line_idx = #out_lines - 1

		-- marker highlight
		table.insert(out_spans, {
			line = line_idx,
			start_col = pad,
			end_col = pad + #marker,
			hl_group = marker_hl,
		})
		-- directory: muted
		local path_start = pad + #marker + 1 -- after "marker "
		if dir ~= "" then
			table.insert(out_spans, {
				line = line_idx,
				start_col = path_start,
				end_col = path_start + #dir,
				hl_group = "AtlasTextMuted",
			})
		end
		-- filename: normal (no extra hl, uses default fg)
		-- +N: green
		local stats_byte_start = #file_line - #file_stats
		table.insert(out_spans, {
			line = line_idx,
			start_col = stats_byte_start,
			end_col = stats_byte_start + #file_add,
			hl_group = "AtlasTextPositive",
		})
		-- -N: red
		local rm_byte_start = stats_byte_start + #file_add + 2
		table.insert(out_spans, {
			line = line_idx,
			start_col = rm_byte_start,
			end_col = rm_byte_start + #file_rm,
			hl_group = "AtlasLogError",
		})
	end

	return out_lines, out_spans
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

	-- Diffstat (above description)
	local ds_lines, ds_spans = render_diffstat(diffstat, width)
	utils.append_block(lines, spans, { lines = ds_lines, highlights = ds_spans })
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

	state.line_map = line_map
	return lines, spans, line_map
end

return M
