local M = {}

local utils = require("atlas.utils")
local highlights = require("atlas.ui.highlights")

---@class AtlasThreadedItem
---@field author string|nil
---@field timestamp string|nil
---@field content string|nil
---@field footer_items string[]|nil
---@field children AtlasThreadedItem[]|nil
---@field meta table|nil
---@field line_map table|nil

---@class AtlasThreadedRenderOpts
---@field padding_x integer|nil
---@field author_hl fun(item: AtlasThreadedItem, author: string): string|nil
---@field content_hl fun(item: AtlasThreadedItem, row: string): string|nil

local function make_line_map_entry(item, part, depth)
	local kind = part
	if (tonumber(depth) or 0) > 0 then
		kind = "thread_" .. part
	end

	local entry = {
		kind = kind,
		item = item,
	}

	if type(item.line_map) == "table" then
		for key, value in pairs(item.line_map) do
			if key ~= "kind" then
				entry[key] = value
			end
		end
	end

	return entry
end

local function default_author_hl(_, author)
	if type(author) ~= "string" or author == "" then
		return "AtlasTextMutedItalic"
	end
	return highlights.dynamic_for(author) or "AtlasTextMuted"
end

local function default_content_hl()
	return nil
end

local function with_map(line_map, line_number, entry)
	if type(entry) == "table" then
		line_map[line_number] = entry
	end
end

local function render_item(lines, spans, line_map, item, depth, branch_prefix, is_last, opts)
	branch_prefix = branch_prefix or ""
	is_last = is_last == true

	local padding_x = tonumber(opts.padding_x) or 2
	local pad = string.rep(" ", padding_x)
	local connector = ""
	local continuation = ""
	if depth > 0 then
		connector = is_last and "└─ " or "├─ "
		continuation = is_last and "   " or "│  "
	end

	local meta_prefix = pad .. branch_prefix .. connector
	local body_prefix = pad .. branch_prefix .. continuation
	if depth == 0 then
		body_prefix = pad
	end

	local author = tostring(item.author or "")
	if author == "" then
		author = "Unknown"
	end

	local timestamp = tostring(item.timestamp or "")
	local meta_text = author
	if timestamp ~= "" then
		meta_text = string.format("%s  %s", author, timestamp)
	end

	local meta_line = meta_prefix .. meta_text
	table.insert(lines, meta_line)
	with_map(line_map, #lines, make_line_map_entry(item, "author", depth))

	if #meta_prefix > 0 then
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #meta_prefix,
			hl_group = "AtlasTextMuted",
		})
	end

	local author_hl = opts.author_hl(item, author)
	if type(author_hl) == "string" and author_hl ~= "" then
		table.insert(spans, {
			line = #lines - 1,
			start_col = #meta_prefix,
			end_col = #meta_prefix + #author,
			hl_group = author_hl,
		})
	end

	table.insert(spans, {
		line = #lines - 1,
		start_col = #meta_prefix + #author,
		end_col = #meta_line,
		hl_group = "AtlasTextMuted",
	})

	local content = tostring(item.content or "")
	if content == "" then
		content = "-"
	end

	for _, row in ipairs(utils.sanitize_markdown_lines(content)) do
		table.insert(lines, body_prefix .. row)
		with_map(line_map, #lines, make_line_map_entry(item, "content", depth))

		if #body_prefix > 0 then
			table.insert(spans, {
				line = #lines - 1,
				start_col = 0,
				end_col = #body_prefix,
				hl_group = "AtlasTextMuted",
			})
		end

		local content_hl = opts.content_hl(item, row)
		if type(content_hl) == "string" and content_hl ~= "" then
			table.insert(spans, {
				line = #lines - 1,
				start_col = #body_prefix,
				end_col = #body_prefix + #row,
				hl_group = content_hl,
			})
		end
	end

	local children = item.children or {}
	local footer_items = item.footer_items or {}
	if #footer_items > 0 then
		local footer_prefix = body_prefix
		if depth == 0 and #children > 0 then
			footer_prefix = pad .. "│ "
		end

		local footer_line = footer_prefix .. "  " .. table.concat(footer_items, "   ")
		table.insert(lines, footer_line)
		with_map(line_map, #lines, make_line_map_entry(item, "footer", depth))
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #footer_line,
			hl_group = "AtlasTextMuted",
		})
	end

	for i, child in ipairs(children) do
		local sep = pad .. branch_prefix .. continuation
		if depth == 0 then
			sep = pad .. "│"
		end

		table.insert(lines, sep)
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #sep,
			hl_group = "AtlasTextMuted",
		})

		render_item(lines, spans, line_map, child, depth + 1, branch_prefix .. continuation, i == #children, opts)
	end
end

---@param items AtlasThreadedItem[]|nil
---@param opts AtlasThreadedRenderOpts|nil
---@return string[], table[], table
function M.render(items, opts)
	local resolved_opts = vim.tbl_extend("force", {
		padding_x = 2,
		author_hl = default_author_hl,
		content_hl = default_content_hl,
	}, opts or {})

	local lines = {}
	local spans = {}
	local line_map = {}
	local list = items or {}

	if #list == 0 then
		return lines, spans, line_map
	end

	for idx, item in ipairs(list) do
		render_item(lines, spans, line_map, item, 0, "", idx == #list, resolved_opts)
		if idx < #list then
			table.insert(lines, "")
		end
	end

	return lines, spans, line_map
end

return M
