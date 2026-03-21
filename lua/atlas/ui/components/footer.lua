local M = {}

local function text_width(text)
	return vim.fn.strdisplaywidth(text or "")
end

local function build_segments_line(segments, line_index)
	local line = ""
	local highlights = {}
	local col = 0

	for _, seg in ipairs(segments or {}) do
		local normalized = vim.trim(tostring(seg.text or ""))
		local text = normalized == "" and "" or (" " .. normalized .. " ")
		line = line .. text

		if seg.hl_group ~= nil and text ~= "" then
			table.insert(highlights, {
				line = line_index,
				start_col = col,
				end_col = col + #text,
				hl_group = seg.hl_group,
			})
		end

		col = col + #text
	end

	return line, highlights
end

-- opts:
--   width: number
--   footer_hl: string (optional, default AtlasFooterBackground)
--   segments: {
--     { text = "PRs", hl_group = "AtlasFooterText" },
--     { text = " | ", hl_group = "AtlasFooterMuted" },
--     { text = "@emrearmagan", hl_group = "AtlasFooterMuted" },
--   }
--   TODO: Its slighty off, fix it
function M.render(opts)
	local width = opts.width or vim.o.columns
	local footer_hl = opts.footer_hl or "AtlasFooterBackground"
	local left_segments, right_segments = {}, {}
	for _, seg in ipairs(opts.segments or {}) do
		if seg.align == "right" then
			table.insert(right_segments, seg)
		else
			table.insert(left_segments, seg)
		end
	end

	local left_line, left_hls = build_segments_line(left_segments, 0)
	local right_line, right_hls = build_segments_line(right_segments, 0)

	local gap = width - text_width(left_line) - text_width(right_line)
	if gap < 1 then
		gap = 1
	end

	local line = left_line .. string.rep(" ", gap) .. right_line
	if text_width(line) < width then
		line = line .. string.rep(" ", width - text_width(line))
	end

	local highlights = {}
	for _, hl in ipairs(left_hls) do
		table.insert(highlights, hl)
	end
	local right_offset = #left_line + gap
	for _, hl in ipairs(right_hls) do
		table.insert(highlights, {
			line = hl.line,
			start_col = hl.start_col + right_offset,
			end_col = hl.end_col + right_offset,
			hl_group = hl.hl_group,
		})
	end

	return {
		lines = { line },
		highlights = vim.list_extend({
			{
				line = 0,
				start_col = 0,
				end_col = math.max(width, 1),
				hl_group = footer_hl,
			},
		}, highlights),
	}
end

return M
