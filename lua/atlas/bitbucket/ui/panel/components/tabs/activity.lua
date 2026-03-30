local M = {}

local utils = require("atlas.utils")
local icons = require("atlas.ui.icons")
local table_view = require("atlas.ui.components.table")
local spinner = require("atlas.ui.components.spinner")
local highlights = require("atlas.ui.highlights")

---@param activity BitbucketPRActivity|"loading"|nil
---@param width integer|nil
---@return string[]
---@return table[]
function M.render(activity, width)
	local lines = {}
	local spans = {}

	if activity == "loading" then
		local loading_line = spinner.with_text("Loading activity...")
		table.insert(lines, loading_line)
		table.insert(spans, {
			line = 0,
			start_col = 0,
			end_col = #loading_line,
			hl_group = "AtlasTextMuted",
		})
		return lines, spans
	end

	local entries = (type(activity) == "table" and activity.entries) or {}
	if type(entries) ~= "table" or #entries == 0 then
		return { "No activity yet." }, spans
	end

	local function first_line(text)
		local raw = tostring(text or ""):gsub("\r\n", "\n")
		return raw:match("([^\n]+)") or raw
	end

	local function actor_name(actor)
		if type(actor) ~= "table" then
			return "Unknown"
		end
		if type(actor.nickname) == "string" and actor.nickname ~= "" then
			return actor.nickname
		end
		if type(actor.name) == "string" and actor.name ~= "" then
			return actor.name
		end
		return "Unknown"
	end

	local function update_detail(entry)
		local changes = type(entry.changes) == "table" and entry.changes or {}
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

	local rows = {}
	for _, e in ipairs(entries) do
		local kind = tostring(e.kind or "")
		local actor = actor_name(e.actor)
		local action = "updated"
		local icon = icons.entity("activity")
		local detail = ""

		if kind == "approval" then
			action = "approved"
			icon = icons.entity("success")
			detail = "approval"
		elseif kind == "comment" then
			action = "commented"
			icon = icons.entity("comment")
			detail = first_line(e.content_raw)
		elseif kind == "update" then
			action = "updated"
			icon = icons.entity("activity")
			detail = update_detail(e)
		end

		table.insert(rows, {
			kind = "event",
			event_kind = kind,
			icon = icon,
			event = action,
			actor = actor,
			date = utils.relative_time(e.date),
		})

		table.insert(rows, {
			kind = "meta",
			event_kind = kind,
			icon = "",
			event = detail,
			actor = "",
			date = "",
			separator = true,
		})
	end

	local table_lines, _, table_spans = table_view.render({
		width = width,
		margin = 0,
		column_gap = 1,
		show_header = false,
		fill = true,
		columns = {
			{ key = "icon", name = "", width = 2, can_grow = false },
			{ key = "event", name = "", min_width = 26, can_grow = true },
			{ key = "actor", name = "", min_width = 12, can_grow = false },
			{ key = "date", name = "", width = 8, can_grow = false },
		},
		rows = rows,
		cell_hl = function(row, col)
			if col.key == "icon" then
				if row.kind ~= "event" then
					return nil
				end
				if row.event_kind == "approval" then
					return "AtlasTextPositive"
				end
				if row.event_kind == "comment" then
					return "AtlasTextMuted"
				end
				return "AtlasTextWarning"
			end
			if row.kind == "meta" and col.key == "event" then
				return "AtlasTextMuted"
			end
			if col.key == "date" then
				return "AtlasTextMuted"
			end
			if row.kind == "event" and col.key == "actor" then
				return highlights.dynamic_for(row.actor)
			end
			return nil
		end,
	})

	for _, line in ipairs(table_lines) do
		table.insert(lines, line)
	end
	for _, span in ipairs(table_spans or {}) do
		table.insert(spans, span)
	end

	return lines, spans
end

return M
