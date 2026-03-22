local M = {}

local utils = require("atlas.utils")

local registry = {
	bitbucket = {},
	jira = {},
	github = {},
}

---@param text string|nil
---@return number
local function text_width(text)
	return vim.fn.strdisplaywidth(text or "")
end

---@param list table[]|nil
---@return table[]
local function clone_segments(list)
	local out = {}
	for _, seg in ipairs(list or {}) do
		table.insert(out, vim.deepcopy(seg))
	end
	return out
end

---@param segments table[]|nil
---@param line_index integer
---@return string
---@return table[]
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

---@param view "bitbucket"|"jira"|"github"
function M.clear_items(view)
	if view ~= nil then
		registry[view] = {}
		return
	end

	for key, _ in pairs(registry) do
		registry[key] = {}
	end
end

---@param view "bitbucket"|"jira"|"github"
---@param seg table
function M.register_item(view, seg)
	registry[view] = registry[view] or {}
	table.insert(registry[view], seg)
end

---@param view "bitbucket"|"jira"|"github"
---@return table[]
function M.segments_for(view)
	local left = clone_segments(registry[view] or {})

	local right = {
		{ text = string.format("atlas (%s)", utils.get_version()), hl_group = "AtlasTextMuted", align = "right" },
		{ text = "? help", hl_group = "AtlasTextMuted", align = "right" },
	}

	for _, seg in ipairs(right) do
		table.insert(left, seg)
	end

	return left
end

-- opts:
--   width: number
--   footer_hl: string (optional, default AtlasFooterBackground)
--   segments: {
--     { text = "PRs", hl_group = "AtlasFooterText" },
--     { text = " | ", hl_group = "AtlasFooterText" },
--     { text = "@emrearmagan", hl_group = "AtlasFooterText" },
--   }
--
---@ opts { width?: number, footer_hl?: string, segments?: table[] }
---@return { lines: string[], highlights: table[] }
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

function M.setup()
	local help = require("atlas.ui.popups.help")
	help.register_keys("General", {
		{
			key = "?",
			desc = "Toggle this help popup",
			callback = function()
				help.toggle()
			end,
		},
	}, { index = 100 })
end

return M
