local M = {}

local layout = require("atlas.ui.layout")
local state = require("atlas.bitbucket.ui.panel.repository.state")
local tabs = require("atlas.bitbucket.ui.panel.components.tabs")

local ns = vim.api.nvim_create_namespace("atlas.bitbucket.panel")
local PADDING_X = 2

local function pad_line(line)
	local pad = string.rep(" ", PADDING_X)
	return pad .. (line or "") .. pad
end

---@param repo table
---@param width integer|nil
---@return string[]
---@return table[]
local function repo_lines(repo, width)
	local _ = width
	local name = tostring(repo.full_name or repo.repo or "Repository")
	local tab = state.current_tab or "overview"
	local tabs_line, tabs_spans = tabs.render_repo(tab)

	local content_title = "Repository"
	if tab == "branches" then
		content_title = "Branches"
	elseif tab == "tags" then
		content_title = "Tags"
	elseif tab == "commits" then
		content_title = "Commits"
	end

	local out_spans = {
		{ line = 0, start_col = 0, end_col = #content_title, hl_group = "AtlasSectionHeader" },
		{ line = 5, start_col = 0, end_col = #name, hl_group = "AtlasTextMuted" },
		{ line = 3, start_col = 0, end_col = math.max((width or 1), 1), hl_group = "AtlasTextMuted" },
	}
	for _, span in ipairs(tabs_spans or {}) do
		table.insert(out_spans, {
			line = 2,
			start_col = span.start_col,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end

	return {
		content_title,
		"",
		tabs_line,
		string.rep("─", math.max((width or 1), 1)),
		"",
		name,
		"",
		"This is a repo",
	}, out_spans
end

---@param repo table
function M.render(repo)
	local buf = layout.buf_id("detail")
	local win = layout.win_id("detail")
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	if win == nil or not vim.api.nvim_win_is_valid(win) then
		return
	end

	local width = vim.api.nvim_win_get_width(win)
	local lines, spans = repo_lines(repo, width - (PADDING_X * 2))

	local out_lines = {}
	for _, line in ipairs(lines or {}) do
		table.insert(out_lines, pad_line(line))
	end

	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, out_lines)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	for _, span in ipairs(spans or {}) do
		vim.api.nvim_buf_set_extmark(buf, ns, span.line, span.start_col + PADDING_X, {
			end_row = span.line,
			end_col = span.end_col + PADDING_X,
			hl_group = span.hl_group,
		})
	end

	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
end

return M
