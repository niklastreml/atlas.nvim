local M = {}

local layout = require("atlas.ui.layout")
local state = require("atlas.bitbucket.ui.panel.repository.state")
local tabs = require("atlas.bitbucket.ui.panel.components.tabs")
local chips = require("atlas.bitbucket.ui.panel.components.chips")
local header = require("atlas.bitbucket.ui.panel.components.header")
local spinner = require("atlas.ui.components.spinner")

local ns = vim.api.nvim_create_namespace("atlas.bitbucket.panel")
local PADDING_X = 2

local function pad_line(line)
	local pad = string.rep(" ", PADDING_X)
	return pad .. (line or "") .. pad
end

---@param repo table
---@param detail BitbucketRepositoryDetail|nil
---@param width integer|nil
---@return string[]
---@return table[]
local function render_overview(repo, detail, width)
	local _ = repo
	local _ = detail
	local _ = width
	return {}, {}
end

---@param repo table
---@param detail BitbucketRepositoryDetail|nil
---@param width integer|nil
---@return string[]
---@return table[]
local function render_branches(repo, detail, width)
	local _ = repo
	local _ = detail
	local _ = width
	return {}, {}
end

---@param repo table
---@param detail BitbucketRepositoryDetail|nil
---@param width integer|nil
---@return string[]
---@return table[]
local function render_tags(repo, detail, width)
	local _ = repo
	local _ = detail
	local _ = width
	return {}, {}
end

---@param repo table
---@param detail BitbucketRepositoryDetail|nil
---@param width integer|nil
---@return string[]
---@return table[]
local function render_commits(repo, detail, width)
	local _ = repo
	local _ = detail
	local _ = width
	return {}, {}
end

---@param tab "overview"|"branches"|"tags"|"commits"
---@param repo table
---@param detail BitbucketRepositoryDetail|nil
---@param width integer|nil
---@return string[]
---@return table[]
local function render_tab_content(tab, repo, detail, width)
	if tab == "overview" then
		return render_overview(repo, detail, width)
	end
	if tab == "branches" then
		return render_branches(repo, detail, width)
	end
	if tab == "tags" then
		return render_tags(repo, detail, width)
	end
	return render_commits(repo, detail, width)
end

---@param repo table
---@param width integer|nil
---@return string[]
---@return table[]
local function repo_lines(repo, width)
	local _ = width
	local tab = state.current_tab or "overview"
	local tabs_line, tabs_spans = tabs.render_repo(tab)
	local detail = state.current_detail

	if detail == "loading" then
		local loading_line = spinner.with_text("Loading...")
		local rows = { loading_line, "", tabs_line, "" }
		local spans = {
			{ line = 0, start_col = 0, end_col = #loading_line, hl_group = "AtlasTextMuted" },
		}
		for _, span in ipairs(tabs_spans or {}) do
			table.insert(spans, {
				line = 2,
				start_col = span.start_col,
				end_col = span.end_col,
				hl_group = span.hl_group,
			})
		end

		local body_lines, body_spans = render_tab_content(tab, repo, nil, width)
		local body_base = #rows
		for _, line in ipairs(body_lines or {}) do
			table.insert(rows, line)
		end
		for _, span in ipairs(body_spans or {}) do
			table.insert(spans, {
				line = body_base + span.line,
				start_col = span.start_col,
				end_col = span.end_col,
				hl_group = span.hl_group,
			})
		end

		return rows, spans
	end

	local chips_line, chips_spans = chips.render_repo(detail)
	local header_detail = type(detail) == "table" and detail
		or {
			is_private = false,
			created_on = "",
			updated_on = "",
		}
	local header_lines, header_spans = header.render_repo(repo, header_detail, width)

	local rows = {}
	local out_spans = {}

	local header_base = #rows
	for _, line in ipairs(header_lines or {}) do
		table.insert(rows, line)
	end
	for _, span in ipairs(header_spans or {}) do
		if span.line_hl_group ~= nil then
			table.insert(out_spans, {
				line = header_base + span.line,
				start_col = 0,
				end_col = 0,
				line_hl_group = span.line_hl_group,
			})
		else
			table.insert(out_spans, {
				line = header_base + span.line,
				start_col = span.start_col,
				end_col = span.end_col,
				hl_group = span.hl_group,
			})
		end
	end

	table.insert(rows, "")
	local chips_line_idx = #rows
	table.insert(rows, chips_line)
	table.insert(rows, "")
	local tabs_line_idx = #rows
	table.insert(rows, tabs_line)
	table.insert(rows, "")

	for _, span in ipairs(chips_spans or {}) do
		table.insert(out_spans, {
			line = chips_line_idx,
			start_col = span.start_col,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end
	for _, span in ipairs(tabs_spans or {}) do
		table.insert(out_spans, {
			line = tabs_line_idx,
			start_col = span.start_col,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end

	local detail_table = type(detail) == "table" and detail or nil
	local body_lines, body_spans = render_tab_content(tab, repo, detail_table, width)
	local body_base = #rows
	for _, line in ipairs(body_lines or {}) do
		table.insert(rows, line)
	end
	for _, span in ipairs(body_spans or {}) do
		table.insert(out_spans, {
			line = body_base + span.line,
			start_col = span.start_col,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end

	return rows, out_spans
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
		local line = tonumber(span.line) or 0
		local line_text = out_lines[line + 1]
		if type(line_text) ~= "string" then
			goto continue
		end

		if span.line_hl_group ~= nil then
			vim.api.nvim_buf_set_extmark(buf, ns, line, 0, {
				line_hl_group = span.line_hl_group,
			})
		else
			local line_len = #line_text
			local start_col = math.max(0, math.min((tonumber(span.start_col) or 0) + PADDING_X, line_len))
			local end_col = math.max(start_col, math.min((tonumber(span.end_col) or 0) + PADDING_X, line_len))

			vim.api.nvim_buf_set_extmark(buf, ns, line, start_col, {
				end_row = line,
				end_col = end_col,
				hl_group = span.hl_group,
			})
		end

		::continue::
	end

	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
end

return M
