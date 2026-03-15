local M = {}

local function pad(text, width)
	text = tostring(text or "")
	local w = vim.fn.strdisplaywidth(text)
	if w >= width then
		return text:sub(1, width)
	end
	return text .. string.rep(" ", width - w)
end

function M.render(columns, rows)
	local lines, line_map, spans = {}, {}, {}

	local header_parts = {}
	local start_col = 2
	for _, c in ipairs(columns or {}) do
		local part = pad(c.title, c.width)
		table.insert(header_parts, part)
		table.insert(spans, {
			line = 0,
			start_col = start_col,
			end_col = start_col + #part,
			hl_group = "AtlasTableHeader",
		})
		start_col = start_col + #part + 2
	end

	table.insert(lines, "  " .. table.concat(header_parts, "  "))
	table.insert(lines, "")

	for _, row in ipairs(rows or {}) do
		local parts = {}
		for _, c in ipairs(columns or {}) do
			table.insert(parts, pad(row[c.key], c.width))
		end
		table.insert(lines, "  " .. table.concat(parts, "  "))
		line_map[#lines] = row
	end

	return lines, line_map, spans
end

return M
