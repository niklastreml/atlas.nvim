---@class PullsOverviewTab : PullsPanelTabModule
local M = {}

local utils = require("atlas.shared.utils")
local icons = require("atlas.shared.icons")
local spinner = require("atlas.ui.components.spinner")
local table_view = require("atlas.ui.components.table_tree")
local state = require("atlas.pulls.ui.panel.tabs.overview.state")

local PADDING_X = 1
local PADDING = string.rep(" ", PADDING_X)

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

--------------------------------------------------------------------------------
-- on_select — cancel previous, kick off new fetches
--------------------------------------------------------------------------------

---@param pr PullRequest
---@param repo PullsRepo|nil
---@param done fun()
function M.on_select(pr, repo, done)
	cancel_all()
	state.reset()

	local provider = get_provider()
	if not provider then
		return
	end

	if type(provider.fetch_reviewers) == "function" then
		state.reviewers = "loading"
		track(provider.fetch_reviewers(pr, function(reviewers, err)
			state.reviewers = err and err or (reviewers or {})
			done()
		end))
	end

	if type(provider.fetch_builds) == "function" then
		state.builds = "loading"
		track(provider.fetch_builds(pr, function(builds, err)
			state.builds = err and err or (builds or {})
			done()
		end))
	end

	if type(provider.fetch_diffstat) == "function" then
		state.diffstat = "loading"
		track(provider.fetch_diffstat(pr, function(entries, err)
			state.diffstat = err and err or (entries or {})
			done()
		end))
	end
end

--------------------------------------------------------------------------------
-- Reviewers
--------------------------------------------------------------------------------

local DECISION_GROUPS = { "approved", "changes_requested", "pending" }

local DECISION_ICONS = {
	approved = { icon = icons.general("success"), hl = "AtlasTextPositive" },
	changes_requested = { icon = icons.general("warning"), hl = "AtlasTextWarning" },
	pending = { icon = icons.general("pending"), hl = "AtlasTextMuted" },
}

---@param pr PullRequest
---@param width integer
---@param lines string[]
---@param spans table[]
local function render_reviewers(pr, width, lines, spans)
	if state.reviewers == nil then
		return
	end

	if state.reviewers == "loading" then
		utils.push(lines, spans, "Reviewers (...)", "AtlasColumnHeader", PADDING_X)
		local header_text = "Reviewers (...)"
		local count_text = "(...)"
		table.insert(spans, {
			line = #lines - 1,
			start_col = PADDING_X + #header_text - #count_text,
			end_col = PADDING_X + #header_text,
			hl_group = "AtlasTextMuted",
		})
		utils.push(lines, spans, spinner.with_text("Loading reviewers..."), "AtlasTextMuted", PADDING_X)
		table.insert(lines, "")
		return
	end

	if type(state.reviewers) == "string" then
		utils.push(lines, spans, "Reviewers", "AtlasColumnHeader", PADDING_X)
		utils.push(lines, spans, state.reviewers, "AtlasLogError", PADDING_X)
		table.insert(lines, "")
		return
	end

	local decisions = state.reviewers
	local approved_count = 0
	for _, r in ipairs(decisions) do
		if r.decision == "approved" then
			approved_count = approved_count + 1
		end
	end

	local header_text = string.format("Reviewers (%d/%d)", approved_count, #decisions)
	utils.push(lines, spans, header_text, "AtlasColumnHeader", PADDING_X)
	local count_text = string.format("(%d/%d)", approved_count, #decisions)
	table.insert(spans, {
		line = #lines - 1,
		start_col = PADDING_X + #header_text - #count_text,
		end_col = PADDING_X + #header_text,
		hl_group = "AtlasTextMuted",
	})

	if #decisions == 0 then
		utils.push(lines, spans, "no reviewers yet", nil, PADDING_X)
		table.insert(lines, "")
		return
	end

	local grouped = { approved = {}, changes_requested = {}, pending = {} }
	for _, d in ipairs(decisions) do
		local s = d.decision or "pending"
		if grouped[s] == nil then
			s = "pending"
		end
		local name = (d.name and d.name ~= "") and d.name
			or (d.nickname and d.nickname ~= "") and d.nickname
			or "Unknown"
		table.insert(grouped[s], name)
	end

	local content_width = math.max(10, width - (PADDING_X * 2))
	for _, s in ipairs(DECISION_GROUPS) do
		local names = grouped[s]
		if #names > 0 then
			table.sort(names)
			local d = DECISION_ICONS[s] or DECISION_ICONS.pending
			local label = table.concat(names, ", ")
			local icon_prefix = d.icon .. " "
			local icon_prefix_width = vim.api.nvim_strwidth(icon_prefix)
			local label_width = math.max(1, content_width - icon_prefix_width)
			local wrapped = utils.wrap_line(label, label_width)

			local line_text = icon_prefix .. wrapped[1]
			table.insert(lines, PADDING .. line_text)
			table.insert(spans, {
				line = #lines - 1,
				start_col = PADDING_X,
				end_col = PADDING_X + #d.icon,
				hl_group = d.hl,
			})

			local continuation_prefix = string.rep(" ", icon_prefix_width)
			for i = 2, #wrapped do
				table.insert(lines, PADDING .. continuation_prefix .. wrapped[i])
			end
		end
	end
	table.insert(lines, "")
end

--------------------------------------------------------------------------------
-- Builds
--------------------------------------------------------------------------------

local BUILD_HL = {
	SUCCESSFUL = "AtlasBuildLinkSuccess",
	FAILED = "AtlasBuildLinkFailed",
	INPROGRESS = "AtlasBuildLinkInProgress",
	STOPPED = "AtlasBuildLinkMuted",
}

---@param status string
---@return string
local function status_label(status)
	local s = tostring(status or ""):lower()
	if s == "" then
		return "Unknown"
	end
	return s:sub(1, 1):upper() .. s:sub(2)
end

---@param pr PullRequest
---@param width integer
---@param lines string[]
---@param spans table[]
---@param line_map table<integer, table>
local function render_builds(pr, width, lines, spans, line_map)
	if state.builds == nil then
		return
	end

	utils.push(lines, spans, "Builds", "AtlasColumnHeader", PADDING_X)

	if state.builds == "loading" then
		utils.push(lines, spans, spinner.with_text("Loading builds..."), "AtlasTextMuted", PADDING_X)
		table.insert(lines, "")
		return
	end

	if type(state.builds) == "string" then
		utils.push(lines, spans, state.builds, "AtlasLogError", PADDING_X)
		table.insert(lines, "")
		return
	end

	local content_width = math.max(10, width - (PADDING_X * 2))
	local entries = state.builds

	if #entries == 0 then
		utils.push(lines, spans, "No builds found", "AtlasTextMuted", PADDING_X)
		table.insert(lines, "")
		return
	end

	for _, entry in ipairs(entries) do
		local s = tostring(entry.state or "UNKNOWN")
		local icon = icons.pulls_status(s:lower())
		local name = tostring(entry.name or entry.key or "Build")
		local text = string.format("%s %s (%s)", icon, name, status_label(s))
		local wrapped = utils.wrap_line(text, content_width)

		for i, chunk in ipairs(wrapped) do
			table.insert(lines, PADDING .. chunk)
			line_map[#lines] = {
				kind = "build",
				build = entry,
				url = tostring(entry.url or ""),
			}
			local hl = i == 1 and (BUILD_HL[s] or "AtlasBuildLinkMuted") or "AtlasBuildLinkMuted"
			table.insert(spans, {
				line = #lines - 1,
				start_col = PADDING_X,
				end_col = PADDING_X + #chunk,
				hl_group = hl,
			})
		end
	end
	table.insert(lines, "")
end

--------------------------------------------------------------------------------
-- Description
--------------------------------------------------------------------------------

---@param pr PullRequest
---@param width integer
---@param lines string[]
---@param spans table[]
local function render_description(pr, width, lines, spans)
	local content_width = math.max(10, width - (PADDING_X * 2))

	utils.push(lines, spans, "Description", "AtlasColumnHeader", PADDING_X)

	local desc_text = tostring(pr.description or "")
	if desc_text == "" then
		utils.push(lines, spans, "No description provided.", "AtlasTextMuted", PADDING_X)
		return
	end

	local desc_lines = utils.sanitize_lines(desc_text)
	for _, line in ipairs(desc_lines) do
		local wrapped = utils.wrap_line(line, content_width)
		for _, chunk in ipairs(wrapped) do
			table.insert(lines, PADDING .. chunk)
		end
	end
end

--------------------------------------------------------------------------------
-- Diffstat
--------------------------------------------------------------------------------

local STATUS_MAP = {
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

---@param pr PullRequest
---@param width integer
---@param lines string[]
---@param spans table[]
local function render_diffstat(pr, width, lines, spans)
	if state.diffstat == nil then
		return
	end

	if state.diffstat == "loading" then
		utils.push(lines, spans, "Files changed", "AtlasColumnHeader", PADDING_X)
		utils.push(lines, spans, spinner.with_text("Loading file changes..."), "AtlasTextMuted", PADDING_X)
		return
	end

	if type(state.diffstat) == "string" then
		utils.push(lines, spans, "Files changed", "AtlasColumnHeader", PADDING_X)
		utils.push(lines, spans, state.diffstat, "AtlasLogError", PADDING_X)
		return
	end

	local entries = state.diffstat
	local hdr = #entries > 0 and string.format("Files changed (%d)", #entries) or "Files changed"
	utils.push(lines, spans, hdr, "AtlasColumnHeader", PADDING_X)

	if #entries == 0 then
		utils.push(lines, spans, "No files changed.", "AtlasTextMuted", PADDING_X)
		return
	end

	local rows = {}
	for _, entry in ipairs(entries) do
		local s = tostring(entry.status or ""):lower()
		local m = STATUS_MAP[s] or { "~", "AtlasTextMuted" }
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

	utils.append_block(lines, spans, { lines = tbl_lines, highlights = tbl_spans })
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

	render_reviewers(pr, width, lines, spans)
	render_builds(pr, width, lines, spans, line_map)
	render_description(pr, width, lines, spans)
	table.insert(lines, "")
	render_diffstat(pr, width, lines, spans)

	return lines, spans, line_map
end

return M
