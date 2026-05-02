---@class PullsFilesTab : PullsPanelTabModule
local M = {}

local utils = require("atlas.ui.shared.utils")
local spinner = require("atlas.ui.components.spinner")
local diff_blocks = require("atlas.ui.components.diff_blocks")
local table_view = require("atlas.ui.components.table_tree")
local footer = require("atlas.ui.components.footer")
local state = require("atlas.pulls.ui.panel.pr.tabs.files.state")

local PADDING_X = 1

---@type { cancel: fun() }[]
local in_flight = {}

---@return PullsProvider|nil
local function get_provider()
	local pulls_state = require("atlas.pulls.state")
	return pulls_state.provider
end

local function cancel_all()
	for _, handle in ipairs(in_flight) do
		handle.cancel()
	end
	in_flight = {}
end

---@param handle { cancel: fun() }|nil
local function track(handle)
	if handle then
		table.insert(in_flight, handle)
	end
end

---@param text string
---@return string
local function pad(text)
	return string.rep(" ", PADDING_X) .. tostring(text or "")
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
			start_col = PADDING_X,
			end_col = PADDING_X + #text,
			hl_group = hl_group,
		})
	end
end

---@param pr PullRequest
---@param repo PullsRepo|nil
---@param refresh fun()
---@param opts { force_refresh: boolean|nil }|nil
function M.on_select(pr, repo, refresh, opts)
	cancel_all()
	state.reset()

	local provider = get_provider()
	if not provider then
		return
	end

	local pr_id = tostring(pr.id or "")
	if type(provider.fetch_diff) == "function" then
		state.diff = "loading"
		footer.notify("loading", string.format("Loading changes for #%s...", pr_id))
		track(provider.fetch_diff(pr, opts, function(files, err)
			if err then
				state.diff = err
				footer.notify("error", string.format("Failed to load changes for #%s", pr_id))
			else
				state.diff = files or {}
				footer.notify("success", string.format("Changes loaded for #%s", pr_id), 1200)
			end
			refresh()
		end))
	end

	if type(provider.fetch_diffstat) == "function" then
		state.diffstat = "loading"
		track(provider.fetch_diffstat(pr, opts, function(entries, err)
			if err then
				state.diffstat = err
			else
				state.diffstat = entries or {}
			end
			refresh()
		end))
	end
end

--------------------------------------------------------------------------------
-- Diffstat summary
--------------------------------------------------------------------------------

local DIFFSTAT_STATUS_MAP = {
	added = { "+", "AtlasTextPositive" },
	removed = { "-", "AtlasLogError" },
	deleted = { "-", "AtlasLogError" },
	renamed = { "R", "AtlasLogWarn" },
	modified = { "~", "AtlasTextMuted" },
}

---@param entry PullsDiffstatEntry
---@return string
local function diffstat_path(entry)
	local s = tostring(entry.status or ""):lower()
	if s == "renamed" and entry.old_path and entry.old_path ~= "" and entry.path ~= "" then
		return entry.old_path .. " → " .. entry.path
	end
	return entry.path or "(unknown file)"
end

---@param width integer
---@param lines string[]
---@param spans table[]
---@param line_map table<integer, table>
local function render_diffstat_summary(width, lines, spans, line_map)
	if not (type(state.diffstat) == "table") then
		return
	end

	local entries = state.diffstat
	if #entries == 0 then
		return
	end

	local total_add, total_del = 0, 0
	for _, entry in ipairs(entries) do
		total_add = total_add + (tonumber(entry.lines_added) or 0)
		total_del = total_del + (tonumber(entry.lines_removed) or 0)
	end

	local collapsed = state.diffstat_collapsed
	local indicator = collapsed and "▸" or "▾"
	local hdr = string.format("%s Files changed (%d)", indicator, #entries)
	local diff_result = diff_blocks.render({ additions = total_add, deletions = total_del })

	if diff_result.text ~= "" then
		local hdr_w = vim.fn.strdisplaywidth(hdr)
		local diff_w = vim.fn.strdisplaywidth(diff_result.text)
		local gap = math.max(1, width - PADDING_X - hdr_w - diff_w)
		local hdr_line = string.rep(" ", PADDING_X) .. hdr .. string.rep(" ", gap) .. diff_result.text
		table.insert(lines, hdr_line)
		local lnum = #lines - 1
		table.insert(spans, { line = lnum, start_col = PADDING_X, end_col = PADDING_X + #hdr, hl_group = "AtlasColumnHeader" })
		local diff_byte_start = PADDING_X + #hdr + gap
		for _, hl in ipairs(diff_result.highlights) do
			table.insert(spans, { line = lnum, start_col = diff_byte_start + hl.start_col, end_col = diff_byte_start + hl.end_col, hl_group = hl.hl_group })
		end
	else
		push(lines, spans, hdr, "AtlasColumnHeader")
	end
	line_map[#lines] = { type = "diffstat_header" }

	if not collapsed then
		local rows = {}
		for _, entry in ipairs(entries) do
			local s = tostring(entry.status or ""):lower()
			local m = DIFFSTAT_STATUS_MAP[s] or { "~", "AtlasTextMuted" }
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
			margin = PADDING_X,
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
				if col.key == "marker" then return row.marker_hl end
				if col.key == "path" then return "AtlasTextMuted" end
				if col.key == "added" then return "AtlasTextPositive" end
				if col.key == "removed" then return "AtlasLogError" end
			end,
		})

		utils.append_block(lines, spans, { lines = tbl_lines, highlights = tbl_spans })
	end

	table.insert(lines, "")
end

--------------------------------------------------------------------------------
-- Render
--------------------------------------------------------------------------------

---@param pr PullRequest
---@param width integer
---@return string[], table[], table<integer, table>|nil
function M.render(pr, width)
	local lines = {}
	local spans = {}
	local line_map = {}
	local max_width = math.max(20, tonumber(width) or 60)

	render_diffstat_summary(width, lines, spans, line_map)

	if state.diff == nil then
		return lines, spans, line_map
	end

	if state.diff == "loading" then
		push(lines, spans, spinner.with_text("Loading file changes..."), "AtlasTextMuted")
		return lines, spans, line_map
	end

	if type(state.diff) == "string" then
		push(lines, spans, state.diff, "AtlasLogError")
		return lines, spans, line_map
	end

	local files = state.diff
	if #files == 0 then
		push(lines, spans, "No diff available.", nil)
		return lines, spans, line_map
	end

	local hunk_counter = 0

	for _, file in ipairs(files) do
		-- File path separator
		local path_label = file.path
		if file.status == "renamed" and file.old_path then
			path_label = file.old_path .. " -> " .. file.path
		end
		local available = math.max(1, max_width - PADDING_X)
		push(lines, spans, utils.truncate(path_label, available, false), "AtlasColumnHeader")

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
				start_col = PADDING_X,
				end_col = PADDING_X + #display_header,
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

	return lines, spans, line_map
end

---@param _pr PullRequest
---@param entry table
---@return boolean|nil
function M.on_enter(_pr, entry)
	if entry.type == "diffstat_header" then
		state.diffstat_collapsed = not state.diffstat_collapsed
		return true
	end
	if entry.type == "hunk_header" then
		state.collapsed_hunks[entry.hunk_idx] = not state.collapsed_hunks[entry.hunk_idx]
		return true
	end
end

---@param entry table|nil
function M.toggle_hunk(entry)
	if entry and entry.type == "diffstat_header" then
		state.diffstat_collapsed = not state.diffstat_collapsed
	elseif entry and entry.type == "hunk_header" then
		state.collapsed_hunks[entry.hunk_idx] = not state.collapsed_hunks[entry.hunk_idx]
	end
end

---@return boolean
function M.toggle_all_hunks()
	if type(state.diff) ~= "table" then
		return false
	end

	local hunk_count = 0
	for _, file in ipairs(state.diff) do
		for _ in ipairs(file.hunks or {}) do
			hunk_count = hunk_count + 1
		end
	end

	if hunk_count == 0 then
		return false
	end

	local should_expand = false
	for idx = 1, hunk_count do
		if state.collapsed_hunks[idx] == true then
			should_expand = true
			break
		end
	end

	state.collapsed_hunks = {}
	if should_expand then
		return true
	end

	for idx = 1, hunk_count do
		state.collapsed_hunks[idx] = true
	end
	return true
end

---@param direction "next"|"prev"
function M.jump_hunk(direction)
	local layout = require("atlas.ui.layout")
	local panel_state = require("atlas.pulls.ui.panel.pr.state")
	local win = layout.win_id("detail")
	local buf = layout.buf_id("detail")
	if not win or not vim.api.nvim_win_is_valid(win) then
		return
	end
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	local line = vim.api.nvim_win_get_cursor(win)[1]
	local max_line = vim.api.nvim_buf_line_count(buf)
	local step = direction == "next" and 1 or -1
	local bound = direction == "next" and max_line or 1
	local line_map = panel_state.line_map or {}

	for lnum = line + step, bound, step do
		local entry = line_map[lnum]
		if entry and entry.type == "hunk_header" then
			vim.api.nvim_win_set_cursor(win, { lnum, 0 })
			return
		end
	end
end

local keymaps = require("atlas.pulls.ui.panel.pr.tabs.files.keymaps")
function M.activate(buf, refresh)
	if buf == nil or refresh == nil then
		return
	end
	keymaps.setup(buf, refresh)
end

function M.deactivate(buf)
	if buf ~= nil then
		keymaps.teardown(buf)
	end
	cancel_all()
end

return M
