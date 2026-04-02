local M = {}

---@class JiraPanelChipItem
---@field text string
---@field hl_group string
---@field active boolean

---@param items JiraPanelChipItem[]
---@param width integer
---@param padding_x integer|nil
---@param align "left"|"right"|nil
---@return string
---@return table[]
function M.render(items, width, padding_x, align)
	local rendered = {}
	for _, item in ipairs(items or {}) do
		if type(item.text) == "string" and item.text ~= "" then
			table.insert(rendered, {
				text = " " .. item.text .. " ",
				hl_group = item.active and item.hl_group or "AtlasTextMuted",
			})
		end
	end

	if #rendered == 0 then
		return "", {}
	end

	local gap = " "
	local content = {}
	for i, chip in ipairs(rendered) do
		table.insert(content, chip.text)
		if i < #rendered then
			table.insert(content, gap)
		end
	end

	local content_text = table.concat(content)
	local pad = math.max(0, padding_x or 0)
	local alignment = (align == "right") and "right" or "left"
	local left
	if alignment == "right" then
		left = math.max(0, width - #content_text - pad)
	else
		left = pad
	end
	local line = string.rep(" ", left) .. content_text

	local spans = {}
	local cursor = left
	for i, chip in ipairs(rendered) do
		table.insert(spans, {
			line = 0,
			start_col = cursor,
			end_col = cursor + #chip.text,
			hl_group = chip.hl_group,
		})
		cursor = cursor + #chip.text
		if i < #rendered then
			cursor = cursor + #gap
		end
	end

	return line, spans
end

return M
