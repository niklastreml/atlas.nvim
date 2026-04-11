local M = {}

local state = require("atlas.bitbucket.panel.tabs.pr.activity.state")
local pr_state = require("atlas.bitbucket.panel.tabs.pr.state")
local header = require("atlas.bitbucket.panel.components.header")
local chips = require("atlas.bitbucket.panel.components.chips")
local tabs = require("atlas.bitbucket.panel.components.tabs")
local utils = require("atlas.utils")
local spinner = require("atlas.ui.components.spinner")
local highlights = require("atlas.ui.utils.highlights")
local threads = require("atlas.ui.components.threadsv2")
local icons = require("atlas.ui.utils.icons")
local pr_helper = require("atlas.bitbucket.panel.tabs.pr.helper")

local PADDING_X = 1

---@param actor {nickname:string?, name:string?}|nil
---@return string
local function actor_name(actor)
	if actor == nil then
		return "Unknown"
	end
	if actor.nickname and actor.nickname ~= "" then
		return actor.nickname
	end
	if actor.name and actor.name ~= "" then
		return actor.name
	end
	return "Unknown"
end

-- ── update change summary ────────────────────────────────────────

---Build a human-readable "additional" text for an update entry.
---@param entry BitbucketPRActivityUpdateEntry
---@return string
local function update_additional(entry)
	local changes = entry.changes or {}

	local keys = {}
	for k, _ in pairs(changes) do
		keys[#keys + 1] = k
	end
	table.sort(keys)

	if #keys == 1 then
		local key = keys[1]
		if key == "description" then
			return "updated description"
		end
		if key == "title" then
			return "updated title"
		end
		if key == "draft" then
			local val = changes.draft
			if type(val) == "table" and val.new == false then
				return "marked as ready"
			end
			return "marked as draft"
		end
		if key == "reviewers" then
			local rev = changes.reviewers or {}
			local added = rev.added or {}
			if #added > 0 then
				local names = {}
				for _, r in ipairs(added) do
					names[#names + 1] = r.display_name or r.nickname or "someone"
				end
				return "added reviewer: " .. table.concat(names, ", ")
			end
			local removed = rev.removed or {}
			if #removed > 0 then
				local names = {}
				for _, r in ipairs(removed) do
					names[#names + 1] = r.display_name or r.nickname or "someone"
				end
				return "removed reviewer: " .. table.concat(names, ", ")
			end
			return "updated reviewers"
		end
	end

	if #keys > 1 then
		return "updated " .. table.concat(keys, ", ")
	end

	-- No explicit changes. fallback to branch info
	local src = entry.source_branch or ""
	local dst = entry.target_branch or ""
	if src ~= "" and dst ~= "" then
		return string.format("updated %s → %s", src, dst)
	end

	return "updated pull request"
end

---@param entry BitbucketPRActivityUpdateEntry
---@return string|nil
local function update_content(entry)
	local changes = entry.changes or {}
	local desc_change = changes.description
	if desc_change == nil then
		return nil
	end

	-- Just indicate "description changed"
	return nil
end

---@param entries BitbucketPRActivityEntry[]
---@param mention_map table<string, string>
---@return AtlasThreadV2Item[]
local function to_thread_items(entries, mention_map)
	local items = {}
	for _, e in ipairs(entries) do
		local kind = e.kind
		local author = actor_name(e.actor)
		local timestamp = utils.relative_time(e.date)

		local additional ---@type string|nil
		local content ---@type string|nil
		local entry_icon = icons.entity("user")

		if kind == "approval" then
			additional = "approved"
			entry_icon = icons.entity("success")
		elseif kind == "comment" then
			additional = "commented"
			local raw = tostring(e.content_raw or ""):gsub("\r\n", "\n")
			local first = raw:match("([^\n]+)") or raw
			first = pr_helper.mentions.resolve(first, mention_map)
			content = first ~= "" and first or "(empty comment)"

			if e.deleted == true then
				content = "(deleted comment)"
			end
		elseif kind == "update" then
			additional = update_additional(e)
			content = update_content(e)
			entry_icon = icons.entity("activity")
		end

		items[#items + 1] = {
			icon = entry_icon,
			author = author,
			right_text = timestamp,
			additional = additional,
			content = content,
			line_map = {
				activity_entry = e,
				activity_actor = e.actor,
			},
		}
	end
	return items
end

-- ── highlight callbacks ──────────────────────────────────────────

---@param item AtlasThreadV2Item
---@param _text string
---@return string|nil
local function additional_hl(item, _text)
	local entry = item.line_map and item.line_map.activity_entry
	if entry == nil then
		return "AtlasTextMuted"
	end
	if entry.kind == "approval" then
		return "AtlasTextPositive"
	end
	return "AtlasTextMuted"
end

---@param item AtlasThreadV2Item
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
	local tab_lines, tab_spans = tabs.render_pr(pr_state.tab, { width = width, padding_x = PADDING_X })
	utils.append_block(lines, spans, { lines = tab_lines, highlights = tab_spans })
	table.insert(lines, "")

	-- Activity content
	if activity == "loading" then
		local loading_line = string.rep(" ", PADDING_X) .. spinner.with_text("Loading activity...")
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
		local empty_line = string.rep(" ", PADDING_X) .. "No activity yet."
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

	local items = to_thread_items(entries, pr_helper.mentions.build_map())
	local item_lines, item_spans, item_map = threads.render(items, width, {
		padding_x = PADDING_X,
		content_max_lines = 3,
		additional_hl = additional_hl,
		content_hl = content_hl,
		icon_hl_fn = function(item)
			local entry = item.line_map and item.line_map.activity_entry
			if entry and entry.kind == "approval" then
				return "AtlasTextPositive"
			end
			local author = vim.trim(tostring(item.author or "")):lower()
			return highlights.dynamic_for(author) or "AtlasTextMuted"
		end,
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
