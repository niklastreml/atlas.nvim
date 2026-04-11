local M = {}

local tab_state = require("atlas.bitbucket.panel.tabs.repo.branches.state")
local state = require("atlas.bitbucket.panel.tabs.repo.state")
local header = require("atlas.bitbucket.panel.components.header")
local chips = require("atlas.bitbucket.panel.components.chips")
local tabs_component = require("atlas.bitbucket.panel.components.tabs")
local threads = require("atlas.ui.components.threadsv2")
local utils = require("atlas.utils")
local spinner = require("atlas.ui.components.spinner")
local icons = require("atlas.ui.utils.icons")
local highlights = require("atlas.ui.utils.highlights")
local PADDING_X = 1

---@param b BitbucketRepositoryBranch
---@return AtlasThreadV2Item
local function to_thread_item(b)
	local msg = tostring(b.message or ""):gsub("\r\n", "\n")
	msg = msg:match("([^\n]+)") or msg

	local author = tostring(b.author or "")
	local when = utils.relative_time(tostring(b.date or ""))

	return {
		icon = icons.entity("branch"),
		icon_hl = "AtlasTextMuted",
		author = tostring(b.name or "-"),
		additional = author,
		right_text = when,
		content = msg,
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

	local repo = tab_state.repo
	local detail = state.detail
	local branches = tab_state.branches

	if repo == nil then
		return { "", "  No repository selected..." }, {}, nil
	end

	-- Header
	if detail ~= nil and detail ~= "loading" then
		local header_lines, header_spans = header.render_repo(repo, detail, width)
		utils.append_block(lines, spans, { lines = header_lines, highlights = header_spans })

		-- Chips
		local chip_line, chip_spans = chips.render_repo(detail)
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
	else
		local loading_line = spinner.with_text("Loading repository...")
		table.insert(lines, loading_line)
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #loading_line,
			hl_group = "AtlasTextMuted",
		})
		table.insert(lines, "")
	end

	-- Tabs
	local tab_lines, tab_spans = tabs_component.render_repo(state.tab, { width = width, padding_x = 1 })
	utils.append_block(lines, spans, { lines = tab_lines, highlights = tab_spans })
	table.insert(lines, "")

	-- Branches content
	if branches == "loading" then
		local loading_line = spinner.with_text("Loading branches...")
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

	if branches == nil or branches.entries == nil or #branches.entries == 0 then
		local empty_line = string.rep(" ", PADDING_X) .. "No branches found."
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

	-- Build thread items
	local items = {}
	for _, b in ipairs(branches.entries) do
		table.insert(items, to_thread_item(b))
	end

	local thread_lines, thread_spans, thread_line_map = threads.render(items, width, {
		padding_x = 1,
		mode = "linked",
		right_text_align = "right",
		content_max_lines = 1,
		author_hl = function()
			return "AtlasText"
		end,
		additional_hl = function(item)
			return highlights.dynamic_for(item.additional or "")
		end,
		content_hl = function(_, row, _)
			return { { start_col = 0, end_col = #row, hl_group = "AtlasTextMuted" } }
		end,
	})
	local thread_base = #lines
	utils.append_block(lines, spans, { lines = thread_lines, highlights = thread_spans })
	for lnum, entry in pairs(thread_line_map or {}) do
		line_map[thread_base + lnum] = entry
	end

	tab_state.line_map = line_map
	return lines, spans, line_map
end

return M
