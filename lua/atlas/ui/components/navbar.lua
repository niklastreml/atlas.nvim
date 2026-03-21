local M = {}

local icons = require("atlas.ui.icons")

local function text_width(text)
	return vim.fn.strdisplaywidth(text)
end

local function title_case(text)
	if text == nil or text == "" then
		return ""
	end
	return text:sub(1, 1):upper() .. text:sub(2)
end

function M.render(opts)
	local width = opts.width or vim.o.columns
	local current_view = opts.current_view or "---"
	local views = opts.views or {}

	local width = opts.width or vim.o.columns
	local items = opts.items or {}

	local actions = {
		{ label = string.format(" %s Refresh (r) ", icons.action("refresh")), hl = "AtlasActionRefresh" },
		{ label = string.format(" %s Help (?) ", icons.action("help")), hl = "AtlasActionHelp" },
	}

	local margin = 2
	local line = string.rep(" ", margin)
	local highlights = {}
	local byte_col = margin
	local display_col = margin

	for _, item in ipairs(items) do
		local icon = item.icon or icons.fallback()
		local label_text = title_case(item.label or "")
		local label = string.format(" %s  %s ", icon, label_text)
		local hl = item.active and "AtlasNavActive" or "AtlasNavInactive"

		line = line .. label .. "  "
		table.insert(highlights, {
			line = 0,
			start_col = byte_col,
			end_col = byte_col + #label,
			hl_group = hl,
		})

		byte_col = byte_col + #label + margin
		display_col = display_col + text_width(label) + margin
	end

	local actions_width = 0
	for i, action in ipairs(actions) do
		actions_width = actions_width + text_width(action.label)
		if i < #actions then
			actions_width = actions_width + 2
		end
	end

	local padding = width - display_col - actions_width - margin
	if padding > 0 then
		line = line .. string.rep(" ", padding)
		byte_col = byte_col + padding
	end

	for i, action in ipairs(actions) do
		line = line .. action.label
		table.insert(highlights, {
			line = 0,
			start_col = byte_col,
			end_col = byte_col + #action.label,
			hl_group = action.hl,
		})

		byte_col = byte_col + #action.label
		if i < #actions then
			line = line .. "  "
			byte_col = byte_col + 2
		end
	end

	return {
		lines = { line },
		highlights = highlights,
	}
end

return M
