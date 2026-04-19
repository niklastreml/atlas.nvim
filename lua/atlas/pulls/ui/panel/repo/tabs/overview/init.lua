---@class PullsRepoOverviewTab : PullsRepoPanelTabModule
local M = {}

local utils = require("atlas.ui.shared.utils")
local spinner = require("atlas.ui.components.spinner")
local state = require("atlas.pulls.ui.panel.repo.state")

local PADDING_X = 1
local PADDING = string.rep(" ", PADDING_X)

---@param text string
---@return string
local function with_padding(text)
	return PADDING .. tostring(text or "")
end

---@param title string
---@param value string|nil
---@param width integer
---@param lines string[]
---@param spans table[]
local function render_text_block(title, value, width, lines, spans)
	utils.push(lines, spans, title, "AtlasColumnHeader", PADDING_X)

	local content = tostring(value or "")
	if content == "" then
		utils.push(lines, spans, "-", "AtlasTextMuted", PADDING_X)
		table.insert(lines, "")
		return
	end

	local content_width = math.max(10, width - (PADDING_X * 2))
	for _, line in ipairs(utils.sanitize_lines(content)) do
		for _, chunk in ipairs(utils.wrap_line(line, content_width)) do
			table.insert(lines, with_padding(chunk))
		end
	end
	table.insert(lines, "")
end

---@param repo PullsRepo
---@param width integer
---@return string[], table[], table<integer, table>
function M.render(repo, width)
	local lines = {}
	local spans = {}

	if repo == nil then
		return { "", "  No repository selected..." }, {}, {}
	end

	local details = state.current_repo_details
	if state.loading_details and details == nil then
		utils.push(lines, spans, spinner.with_text("Loading repository..."), "AtlasTextMuted", PADDING_X)
		return lines, spans, {}
	end

	if details == nil then
		render_text_block("Description", nil, width, lines, spans)
		render_text_block("README", nil, width, lines, spans)
		return lines, spans, {}
	end

	render_text_block("Description", details.description, width, lines, spans)

	if state.loading_details then
		utils.push(lines, spans, "README", "AtlasColumnHeader", PADDING_X)
		utils.push(lines, spans, spinner.with_text("Loading readme..."), "AtlasTextMuted", PADDING_X)
		return lines, spans, {}
	end

	render_text_block("README", details.readme, width, lines, spans)
	return lines, spans, {}
end

return M
