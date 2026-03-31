local M = {}
local spinner = require("atlas.ui.components.spinner")
local utils = require("atlas.utils")
local icons = require("atlas.ui.icons")
local table_view = require("atlas.ui.components.table")
local highlights = require("atlas.ui.highlights")

---@param repo table
---@param detail BitbucketRepositoryDetail|nil
---@param width integer|nil
---@return string[]
---@return table[]
function M.render(repo, detail, width)
	local _ = repo
	if detail == nil then
		local line = spinner.with_text("Loading tags...")
		return { line }, {
			{ line = 0, start_col = 0, end_col = #line, hl_group = "AtlasTextMuted" },
		}
	end

	local repo_state = require("atlas.bitbucket.ui.panel.repository.state")
	local tags = repo_state.current_tags
	if tags == "loading" or tags == nil then
		local line = spinner.with_text("Loading tags...")
		return { line }, {
			{ line = 0, start_col = 0, end_col = #line, hl_group = "AtlasTextMuted" },
		}
	end

	local rows = {}
	for _, t in ipairs((tags.entries or {})) do
		local msg = tostring(t.message or ""):gsub("\r\n", "\n")
		msg = msg:match("([^\n]+)") or msg
		local hash = tostring(t.hash or "")
		hash = hash:sub(1, 12)
		table.insert(rows, {
			tag = tostring(t.name or "-"),
			hash = hash,
			message = msg,
			author = tostring(t.author or "-"),
			timestamp = utils.relative_time(tostring(t.date or "")),
		})
	end

	if #rows == 0 then
		local line = "No tags found."
		return { line }, {
			{ line = 0, start_col = 0, end_col = #line, hl_group = "AtlasTextMuted" },
		}
	end

	local table_lines, _, table_spans = table_view.render({
		width = width,
		margin = 0,
		column_gap = 1,
		show_header = true,
		fill = true,
		columns = {
			{ key = "tag", name = icons.entity("tag"), can_grow = false },
			{ key = "hash", name = "Hash", can_grow = false },
			{ key = "message", name = "Message", min_width = 24, can_grow = true },
			{ key = "author", name = "Author", can_grow = false },
			{ key = "timestamp", name = icons.entity("updated"), can_grow = false },
		},
		rows = rows,
		cell_hl = function(row, col)
			if col.key == "hash" then
				return highlights.dynamic_for(row.hash)
			end
			if col.key == "message" then
				return "AtlasTextMuted"
			end
			if col.key == "timestamp" then
				return "AtlasTextMuted"
			end
			if col.key == "author" then
				return highlights.dynamic_for(row.author)
			end
			return nil
		end,
	})

	return table_lines, table_spans
end

return M
