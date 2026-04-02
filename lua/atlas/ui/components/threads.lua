local M = {}

local utils = require("atlas.utils")
local highlights = require("atlas.ui.highlights")

---@class AtlasThreadedItem
---@field author string|nil
---@field timestamp string|nil
---@field header_content string|nil
---@field content string|nil
---@field footer_items string[]|nil
---@field children AtlasThreadedItem[]|nil
---@field meta table|nil
---@field line_map table|nil

---@class AtlasThreadedRenderOpts
---@field padding_x integer|nil
---@field author_hl fun(item: AtlasThreadedItem, author: string): string|nil
---@field header_content_hl fun(item: AtlasThreadedItem, header_content: string): string|nil
---@field content_hl fun(item: AtlasThreadedItem, row: string): table[]|nil

local function line_map_entry(item, part, depth)
	local kind = part
	if (tonumber(depth) or 0) > 0 then
		kind = "thread_" .. part
	end

	local map = {
		kind = kind,
		item = item,
	}

	if type(item.line_map) == "table" then
		for key, value in pairs(item.line_map) do
			if key ~= "kind" then
				map[key] = value
			end
		end
	end

	return map
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

local function default_header_content_hl()
	return nil
end

local function put_map(line_map, line_number, map)
	if type(map) == "table" then
		line_map[line_number] = map
	end
end

local function add_span(spans, line, start_col, end_col, hl_group)
	table.insert(spans, {
		line = line,
		start_col = start_col,
		end_col = end_col,
		hl_group = hl_group,
	})
end

local function prefixed_line(parts)
	return table.concat(parts, "")
end

local function root_separator_line(width, padding_x)
	local content_width = math.max(8, (tonumber(width) or 0) - (padding_x * 2))
	return string.rep(" ", padding_x) .. string.rep("─", content_width)
end

local function get_prefixes(depth, branch_prefix, is_last, padding_x)
	local pad = string.rep(" ", padding_x)
	local connector = ""
	local continuation = ""

	if depth > 0 then
		connector = is_last and "└─ " or "├─ "
		continuation = is_last and "   " or "│  "
	end

	local meta_prefix = prefixed_line({ pad, branch_prefix, connector })
	local body_prefix = depth == 0 and pad or prefixed_line({ pad, branch_prefix, continuation })

	return pad, continuation, meta_prefix, body_prefix
end

local function render_meta(lines, spans, line_map, item, depth, meta_prefix, opts)
	local author = tostring(item.author or "")
	if author == "" then
		author = "Unknown"
	end

	local timestamp = tostring(item.timestamp or "")
	local header_content = tostring(item.header_content or "")

	local meta_line = meta_prefix .. author
	local author_start = #meta_prefix
	local author_end = author_start + #author
	local header_start, header_end = nil, nil
	local timestamp_start = nil

	if header_content ~= "" then
		meta_line = meta_line .. " " .. header_content
		header_start = author_end + 1
		header_end = header_start + #header_content
	end

	if timestamp ~= "" then
		timestamp_start = #meta_line + 2
		meta_line = meta_line .. "  " .. timestamp
	end

	table.insert(lines, meta_line)
	put_map(line_map, #lines, line_map_entry(item, "author", depth))

	if #meta_prefix > 0 then
		add_span(spans, #lines - 1, 0, #meta_prefix, "AtlasTextMuted")
	end

	local author_hl = opts.author_hl(item, author)
	if type(author_hl) == "string" and author_hl ~= "" then
		add_span(spans, #lines - 1, author_start, author_end, author_hl)
	end

	if type(header_start) == "number" and type(header_end) == "number" then
		local header_content_hl = opts.header_content_hl(item, header_content)
		if type(header_content_hl) == "string" and header_content_hl ~= "" then
			add_span(spans, #lines - 1, header_start, header_end, header_content_hl)
		end
	end

	if type(timestamp_start) == "number" then
		add_span(spans, #lines - 1, timestamp_start, #meta_line, "AtlasTextMuted")
	end
end

local function render_content(lines, spans, line_map, item, depth, body_prefix, opts)
	local raw_content = item.content
	if raw_content == nil then
		return
	end

	local content = tostring(raw_content)

	for _, row in ipairs(utils.sanitize_markdown_lines(content)) do
		table.insert(lines, body_prefix .. row)
		put_map(line_map, #lines, line_map_entry(item, "content", depth))

		if #body_prefix > 0 then
			add_span(spans, #lines - 1, 0, #body_prefix, "AtlasTextMuted")
		end

		local content_hl = opts.content_hl(item, row)
		if content_hl then
			for _, segment in ipairs(content_hl) do
				add_span(
					spans,
					#lines - 1,
					#body_prefix + segment.start_col,
					#body_prefix + segment.end_col,
					segment.hl_group
				)
			end
		end
	end
end

local function render_footer(lines, spans, line_map, item, depth, body_prefix, pad, has_children)
	local footer_items = item.footer_items or {}
	if #footer_items == 0 then
		return
	end

	local footer_prefix = body_prefix
	if depth == 0 and has_children then
		footer_prefix = pad .. "│ "
	end

	local footer_line = footer_prefix .. table.concat(footer_items, "   ")
	table.insert(lines, footer_line)
	put_map(line_map, #lines, line_map_entry(item, "footer", depth))
	add_span(spans, #lines - 1, 0, #footer_line, "AtlasTextMuted")
end

local function render_item(lines, spans, line_map, item, depth, branch_prefix, is_last, opts)
	branch_prefix = branch_prefix or ""
	is_last = is_last == true

	local pad, continuation, meta_prefix, body_prefix =
		get_prefixes(depth, branch_prefix, is_last, tonumber(opts.padding_x) or 2)
	render_meta(lines, spans, line_map, item, depth, meta_prefix, opts)
	render_content(lines, spans, line_map, item, depth, body_prefix, opts)

	local children = item.children or {}
	render_footer(lines, spans, line_map, item, depth, body_prefix, pad, #children > 0)

	for i, child in ipairs(children) do
		local sep = pad .. branch_prefix .. continuation
		if depth == 0 then
			sep = pad .. "│"
		end

		table.insert(lines, sep)
		add_span(spans, #lines - 1, 0, #sep, "AtlasTextMuted")

		render_item(lines, spans, line_map, child, depth + 1, branch_prefix .. continuation, i == #children, opts)
	end
end

---@param items AtlasThreadedItem[]|nil
---@param width integer
---@param opts AtlasThreadedRenderOpts|nil
---@return string[], table[], table
function M.render(items, width, opts)
	local resolved_opts = vim.tbl_extend("force", {
		padding_x = 2,
		author_hl = default_author_hl,
		header_content_hl = default_header_content_hl,
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
			local separator = root_separator_line(width, tonumber(resolved_opts.padding_x) or 2)
			table.insert(lines, separator)
			add_span(spans, #lines - 1, 0, #separator, "AtlasTextMuted")
		end
	end

	return lines, spans, line_map
end

return M
