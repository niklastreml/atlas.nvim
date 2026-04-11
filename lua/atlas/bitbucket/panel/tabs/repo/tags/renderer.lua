local M = {}

local tab_state = require("atlas.bitbucket.panel.tabs.repo.tags.state")
local state = require("atlas.bitbucket.panel.tabs.repo.state")
local header = require("atlas.bitbucket.panel.components.header")
local chips = require("atlas.bitbucket.panel.components.chips")
local tabs_component = require("atlas.bitbucket.panel.components.tabs")
local threads = require("atlas.ui.components.threadsv2")
local utils = require("atlas.utils")
local spinner = require("atlas.ui.components.spinner")
local icons = require("atlas.ui.utils.icons")
local PADDING_X = 1

---@param t BitbucketRepositoryTag
---@return AtlasThreadV2Item
local function to_thread_item(t)
	local msg = tostring(t.message or ""):gsub("\r\n", "\n")
	msg = msg:match("([^\n]+)") or msg

	local author = tostring(t.author or "")
	local hash = tostring(t.hash or ""):sub(1, 8)
	local when = utils.relative_time(tostring(t.date or ""))

	return {
		icon = icons.entity("tag"),
		icon_hl = "AtlasTextMuted",
		author = tostring(t.name or "-"),
		additional = hash,
		right_text = when,
		content = author .. " · " .. msg,
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
	local tags = tab_state.tags

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

	-- Tags content
	if tags == "loading" then
		local loading_line = spinner.with_text("Loading tags...")
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

	if tags == nil or tags.entries == nil or #tags.entries == 0 then
		local empty_line = string.rep(" ", PADDING_X) .. "No tags found."
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
	for _, t in ipairs(tags.entries) do
		table.insert(items, to_thread_item(t))
	end

	local thread_lines, thread_spans, thread_line_map = threads.render(items, width, {
		padding_x = 1,
		mode = "linked",
		right_text_align = "right",
		content_max_lines = 1,
		author_hl = function()
			return "AtlasText"
		end,
		additional_hl = function()
			return "AtlasTextMuted"
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
