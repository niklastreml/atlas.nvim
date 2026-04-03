local M = {}

local state = require("atlas.bitbucketv2.panel.tabs.repo.overview.state")
local panel_state = require("atlas.bitbucketv2.panel.state")
local header = require("atlas.bitbucketv2.panel.components.header")
local chips = require("atlas.bitbucketv2.panel.components.chips")
local tabs_component = require("atlas.bitbucketv2.panel.components.tabs")
local utils = require("atlas.utils")
local spinner = require("atlas.ui.components.spinner")

---@param width integer
---@return string[] lines
---@return table[] spans
---@return table|nil line_map
function M.render(width)
	local lines = {}
	local spans = {}
	local line_map = {}

	local repo = state.repo
	local detail = panel_state.current_repo_detail
	local readme = panel_state.current_repo_readme

	if repo == nil then
		return { "", "  No repository selected..." }, {}, nil
	end

	-- Header
	if detail ~= nil and detail ~= "loading" then
		local header_lines, header_spans = header.render_repo(repo, detail, width)
		for _, line in ipairs(header_lines) do
			table.insert(lines, line)
		end
		for _, span in ipairs(header_spans) do
			table.insert(spans, span)
		end

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
	local tab_lines, tab_spans = tabs_component.render_repo(panel_state.current_tab, width, 0)
	local tab_base = #lines
	for _, line in ipairs(tab_lines) do
		table.insert(lines, line)
	end
	for _, span in ipairs(tab_spans) do
		table.insert(spans, {
			line = tab_base + span.line,
			start_col = span.start_col,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end
	table.insert(lines, "")

	-- Readme content
	if readme == "loading" then
		local loading_line = spinner.with_text("Loading readme...")
		table.insert(lines, loading_line)
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #loading_line,
			hl_group = "AtlasTextMuted",
		})
		state.line_map = line_map
		return lines, spans, line_map
	end

	if type(readme) == "string" and readme ~= "" then
		local readme_lines = utils.sanitize_lines(readme)
		for _, line in ipairs(readme_lines) do
			table.insert(lines, line)
		end
	else
		table.insert(lines, "No readme available.")
	end

	state.line_map = line_map
	return lines, spans, line_map
end

return M
