local M = {}
local icons = require("atlas.ui.icons")

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
	local current_view = opts.current_view or "bitbucket"
	local icon = icons.provider(current_view)
	local title = string.format("  %s  Atlas (%s)  ", icon, current_view)
	local inner = math.max(width - 2, 20)
	local line, start_col = center_text(title, inner)

	return {
		lines = { line, "" },
		highlights = {
			{
				line = 0,
				start_col = start_col,
				end_col = start_col + #title,
				hl_group = "AtlasTitleBitbucket", --- TODO: Fix me
			},
		},
	}
end

return M
