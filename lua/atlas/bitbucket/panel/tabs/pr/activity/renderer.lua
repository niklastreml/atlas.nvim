local M = {}

local state = require("atlas.bitbucket.panel.tabs.pr.activity.state")
local header = require("atlas.bitbucket.panel.components.header")
local chips = require("atlas.bitbucket.panel.components.chips")
local tabs = require("atlas.bitbucket.panel.components.tabs")
local utils = require("atlas.utils")
local spinner = require("atlas.ui.components.spinner")
local highlights = require("atlas.ui.highlights")
local threads = require("atlas.ui.components.threads")

local PADDING_X = 2

---@param width integer
---@return string[] lines
---@return table[] spans
---@return table|nil line_map
function M.render(width)
	local lines = {}
	local spans = {}
	local line_map = {}

	local pr = state.pr
	local activity = state.activity

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
	local panel_state = require("atlas.bitbucket.panel.state")
	local tab_lines, tab_spans = tabs.render_pr(panel_state.current_tab, { width = width, padding_x = 1 })
	utils.append_block(lines, spans, { lines = tab_lines, highlights = tab_spans })
	table.insert(lines, "")

	-- Activity content
	if activity == "loading" then
		local loading_line = spinner.with_text("Loading activity...")
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

	local entries = (activity ~= nil and activity.entries) or {}
	if #entries == 0 then
		table.insert(lines, "No activity yet.")
		state.line_map = line_map
		return lines, spans, line_map
	end

	local function first_line(text)
		local raw = tostring(text or ""):gsub("\r\n", "\n")
		return raw:match("([^\n]+)") or raw
	end

	local function actor_name(actor)
		if actor == nil then
			return "Unknown"
		end
		if actor.nickname ~= "" then
			return actor.nickname
		end
		if actor.name ~= "" then
			return actor.name
		end
		return "Unknown"
	end

	local function update_detail(entry)
		local changes = entry.changes or {}
		local keys = {}
		for key, _ in pairs(changes) do
			table.insert(keys, tostring(key))
		end
		table.sort(keys)
		if #keys > 0 then
			return "changes: " .. table.concat(keys, ", ")
		end

		local source_branch = tostring(entry.source_branch or "")
		local target_branch = tostring(entry.target_branch or "")
		if source_branch ~= "" and target_branch ~= "" then
			return string.format("%s -> %s", source_branch, target_branch)
		end

		return "pull request updated"
	end

	---@param entry BitbucketPRActivityEntry
	---@return string
	local function entry_header(entry)
		local kind = entry.kind
		if kind == "approval" then
			return "approved this pull request"
		end
		if kind == "comment" then
			return "commented on this pull request"
		end
		return "updated this pull request"
	end

	---@param entry BitbucketPRActivityEntry
	---@return string|nil
	local function entry_content(entry)
		local kind = entry.kind
		if kind == "approval" then
			return "approval"
		end
		if kind == "comment" then
			local text = first_line(entry.content_raw)
			if text == "" then
				return "(empty comment)"
			end
			return text
		end
		if kind == "update" then
			return update_detail(entry)
		end
		return nil
	end

	---@param entry BitbucketPRActivityEntry
	---@return string[]|nil
	local function entry_footer(entry)
		if entry.kind ~= "comment" then
			return nil
		end

		local items = {}
		if entry.pending == true then
			table.insert(items, "PENDING")
		end
		if entry.deleted == true then
			table.insert(items, "DELETED")
		end

		return #items > 0 and items or nil
	end

	---@param item AtlasThreadedItem
	---@param author string
	---@return string|nil
	local function author_hl(item, author)
		if author == "" then
			return "AtlasTextMutedItalic"
		end
		local actor = item.line_map and item.line_map.activity_actor
		local key = actor ~= nil and (actor.nickname or actor.name) or author
		return highlights.dynamic_for(key)
	end

	---@param item AtlasThreadedItem
	---@param _text string
	---@return string|nil
	local function header_content_hl(item, _text)
		local entry = item.line_map and item.line_map.activity_entry
		local kind = entry ~= nil and entry.kind or ""
		if kind == "approval" then
			return "AtlasTextPositive"
		end
		if kind == "comment" then
			return "AtlasTextMuted"
		end
		return "AtlasTextWarning"
	end

	---@param item AtlasThreadedItem
	---@param row string
	---@param _row_index integer
	---@return table[]|nil
	local function content_hl(item, row, _row_index)
		local entry = item.line_map and item.line_map.activity_entry
		if entry == nil then
			return nil
		end

		if entry.kind == "comment" and entry.deleted == true then
			return {
				{ start_col = 0, end_col = #row, hl_group = "AtlasTextMutedStrikethrough" },
			}
		end

		if entry.kind == "update" then
			return {
				{ start_col = 0, end_col = #row, hl_group = "AtlasTextMuted" },
			}
		end

		return nil
	end

	local items = {}
	for _, e in ipairs(entries) do
		table.insert(items, {
			author = actor_name(e.actor),
			timestamp = utils.relative_time(e.date),
			header_content = entry_header(e),
			content = entry_content(e),
			footer_items = entry_footer(e),
			line_map = {
				activity_entry = e,
				activity_actor = e.actor,
			},
		})
	end

	local item_lines, item_spans, item_map = threads.render(items, width, {
		padding_x = PADDING_X,
		author_hl = author_hl,
		header_content_hl = header_content_hl,
		content_hl = content_hl,
	})

	local offset = #lines
	utils.append_block(lines, spans, { lines = item_lines, highlights = item_spans })
	for lnum, entry in pairs(item_map or {}) do
		line_map[offset + lnum] = entry
	end

	line_map[1] = line_map[1] or { kind = "pr", pr = pr }
	line_map[#lines] = line_map[#lines] or { kind = "activity" }

	state.line_map = line_map
	return lines, spans, line_map
end

return M
