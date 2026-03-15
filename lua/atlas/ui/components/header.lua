local M = {}

local function center_text(text, width)
	local content_width = vim.fn.strdisplaywidth(text)
	if content_width >= width then
		return text, 0
	end
	local left_pad = math.floor((width - content_width) / 2)
	return string.rep(" ", left_pad) .. text, left_pad
end

---@param opts { width: number, title: string }
function M.render(opts)
	local width = opts.width or vim.o.columns
	local title = opts.title or "Atlas"
	local padded, start_col = center_text(title, math.max(width - 2, 1))

	return {
		lines = { padded, "" },
		highlights = {
			{
				line = 0,
				start_col = start_col,
				end_col = start_col + #title,
				hl_group = "AtlasHeader",
			},
		},
	}
end

return M
