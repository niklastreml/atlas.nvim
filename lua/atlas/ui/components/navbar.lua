local M = {}

---@param opts { current_view: string, views: string[], width: number }
---@return { lines: string[], highlights: table[] }
function M.render(opts)
	local width = opts.width or vim.o.columns
	local current_view = opts.current_view
	local views = opts.views or {}

	local actions = {
		{ label = " Refresh (R) ", hl = "AtlasActionRefresh" },
		{ label = " Help (?) ", hl = "AtlasActionHelp" },
	}

	local line = "  "
	local highlights = {}
	local col = 2

	for _, view in ipairs(views) do
		local is_active = view == current_view
		local label = " " .. view .. " "
		line = line .. label .. "  "
		table.insert(highlights, {
			line = 0,
			start_col = col,
			end_col = col + #label,
			hl_group = is_active and "AtlasNavActive" or "AtlasNavInactive",
		})
		col = col + #label + 2
	end

	local actions_text = ""
	for i, action in ipairs(actions) do
		actions_text = actions_text .. action.label
		if i < #actions then
			actions_text = actions_text .. "  "
		end
	end

	local pad = width - vim.fn.strdisplaywidth(line) - vim.fn.strdisplaywidth(actions_text) - 2
	if pad > 0 then
		line = line .. string.rep(" ", pad)
		col = col + pad
	end

	for i, action in ipairs(actions) do
		line = line .. action.label
		table.insert(highlights, {
			line = 0,
			start_col = col,
			end_col = col + #action.label,
			hl_group = action.hl,
		})
		col = col + #action.label
		if i < #actions then
			line = line .. "  "
			col = col + 2
		end
	end

	return { lines = { line }, highlights = highlights }
end

return M
