local M = {}

local state = require("atlas.bitbucket.panel.tabs.pr.commits.state")
local pr_state = require("atlas.bitbucket.panel.tabs.pr.state")
local header = require("atlas.bitbucket.panel.components.header")
local chips = require("atlas.bitbucket.panel.components.chips")
local tabs_component = require("atlas.bitbucket.panel.components.tabs")
local threads = require("atlas.ui.components.threadsv2")
local utils = require("atlas.utils")
local icons = require("atlas.ui.utils.icons")
local spinner = require("atlas.ui.components.spinner")
local PADDING_X = 1

---@param commit BitbucketPRCommit
---@return AtlasThreadV2Item
local function to_thread_item(commit)
	local message = tostring(commit.message or ""):gsub("\r\n", "\n")
	message = message:match("([^\n]+)") or message

	local author = (commit.author_nickname ~= "" and commit.author_nickname) or commit.author_name or "Unknown"
	local hash = tostring(commit.short_hash or commit.hash or ""):sub(1, 8)
	local when = utils.relative_time(commit.date)

	return {
		icon = icons.entity("commit"),
		icon_hl = "AtlasTextMuted",
		author = message,
		right_text = hash,
		content = author .. " · " .. when,
		line_map = {
			commit = commit,
		},
	}
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
	local commits = state.commits

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
	local tab_lines, tab_spans = tabs_component.render_pr(pr_state.tab, { width = width, padding_x = PADDING_X })
	utils.append_block(lines, spans, { lines = tab_lines, highlights = tab_spans })
	table.insert(lines, "")

	-- Commits content
	if commits == "loading" then
		local loading_line = string.rep(" ", PADDING_X) .. spinner.with_text("Loading commits...")
		table.insert(lines, loading_line)
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #loading_line,
			hl_group = "AtlasTextMuted",
		})
		state.line_map = line_map
		return lines, spans, line_map
	end

	local entries = (commits ~= nil and commits.entries) or {}
	if #entries == 0 then
		local empty_line = string.rep(" ", PADDING_X) .. "No commits yet."
		table.insert(lines, empty_line)
		table.insert(spans, {
			line = #lines - 1,
			start_col = PADDING_X,
			end_col = #empty_line,
			hl_group = "AtlasTextMuted",
		})
		state.line_map = line_map
		return lines, spans, line_map
	end

	local items = {}
	for _, commit in ipairs(entries) do
		table.insert(items, to_thread_item(commit))
	end

	local thread_lines, thread_spans, thread_map = threads.render(items, width, {
		padding_x = PADDING_X,
		mode = "linked",
		right_text_align = "right",
		author_hl = function()
			return "AtlasText"
		end,
		content_hl = function(_, row, _)
			return { { start_col = 0, end_col = #row, hl_group = "AtlasTextMuted" } }
		end,
	})
	local offset = #lines
	utils.append_block(lines, spans, { lines = thread_lines, highlights = thread_spans })
	for lnum, entry in pairs(thread_map or {}) do
		line_map[offset + lnum] = entry
	end

	state.line_map = line_map
	return lines, spans, line_map
end

return M
