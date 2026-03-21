local M = {}

local function center_text(text, width)
	local content_width = vim.fn.strdisplaywidth(text)
	if content_width >= width then
		return text, 0
	end
	local left_pad = math.floor((width - content_width) / 2)
	return string.rep(" ", left_pad) .. text, left_pad
end

function M.render(opts)
	local width = opts.width or vim.o.columns
	local icon = opts.icon or "•"
	local title = opts.title or "Atlas"
	local hl_group = opts.hl_group or "Title"

	local text = string.format("  %s  %s  ", icon, title)
	local line, start_col = center_text(text, math.max(width - 2, 20))

	return {
		lines = { line, "" },
		highlights = {
			{ line = 0, start_col = start_col, end_col = start_col + #text, hl_group = hl_group },
		},
	}
end

return M
