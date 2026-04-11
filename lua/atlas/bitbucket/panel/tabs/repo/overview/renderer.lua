local M = {}

local tab_state = require("atlas.bitbucket.panel.tabs.repo.overview.state")
local state = require("atlas.bitbucket.panel.tabs.repo.state")
local header = require("atlas.bitbucket.panel.components.header")
local chips = require("atlas.bitbucket.panel.components.chips")
local tabs_component = require("atlas.bitbucket.panel.components.tabs")
local utils = require("atlas.utils")
local spinner = require("atlas.ui.components.spinner")

local CONTENT_PADDING_X = 2

---@param text string
---@return string
local function with_content_padding(text)
	return string.rep(" ", CONTENT_PADDING_X) .. tostring(text or "")
end

---@param width integer
---@return string[] lines
---@return table[] spans
---@return table|nil line_map
function M.render(width)
	local lines = {}
	local spans = {}
	local line_map = {}

	local repo = tab_state.repo
	local detail = state.detail
	local readme = tab_state.readme

	if repo == nil then
		return { "", "  No repository selected..." }, {}, nil
	end

	-- Header
	if detail ~= nil and detail ~= "loading" then
		local header_lines, header_spans = header.render_repo(repo, detail, width)
		utils.append_block(lines, spans, { lines = header_lines, highlights = header_spans })

		-- Chips
		local chip_line, chip_spans = chips.render_repo(detail)
		table.insert(lines, chip_line)
		local chip_base = #lines - 1
		for _, span in ipairs(chip_spans) do
			table.insert(spans, {
				line = chip_base,
				start_col = span.start_col,
				end_col = span.end_col,
				hl_group = span.hl_group,
			})
		end
		table.insert(lines, "")
	else
		local loading_line = spinner.with_text("Loading repository...")
		table.insert(lines, loading_line)
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #loading_line,
			hl_group = "AtlasTextMuted",
		})
		table.insert(lines, "")
	end

	-- Tabs
	local tab_lines, tab_spans = tabs_component.render_repo(state.tab, { width = width, padding_x = 1 })
	utils.append_block(lines, spans, { lines = tab_lines, highlights = tab_spans })
	table.insert(lines, "")

	-- Readme content
	if readme == "loading" then
		local loading_text = spinner.with_text("Loading readme...")
		local loading_line = with_content_padding(loading_text)
		table.insert(lines, loading_line)
		table.insert(spans, {
			line = #lines - 1,
			start_col = CONTENT_PADDING_X,
			end_col = CONTENT_PADDING_X + #loading_text,
			hl_group = "AtlasTextMuted",
		})
		tab_state.line_map = line_map
		return lines, spans, line_map
	end

	if type(readme) == "string" and readme ~= "" then
		local content_width = math.max(10, width - (CONTENT_PADDING_X * 2))
		local readme_lines = utils.sanitize_lines(readme)
		for _, line in ipairs(readme_lines) do
			local wrapped = utils.wrap_line(line, content_width)
			for _, chunk in ipairs(wrapped) do
				table.insert(lines, with_content_padding(chunk))
			end
		end
		--- Some spacing
		table.insert(lines, "")
		table.insert(lines, "")
	else
		table.insert(lines, with_content_padding("No readme available."))
	end

	tab_state.line_map = line_map
	return lines, spans, line_map
end

return M
