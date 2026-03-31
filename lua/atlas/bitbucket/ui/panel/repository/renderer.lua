local M = {}

local layout = require("atlas.ui.layout")
local state = require("atlas.bitbucket.ui.panel.repository.state")
local tabs = require("atlas.bitbucket.ui.panel.components.tabs")
local chips = require("atlas.bitbucket.ui.panel.components.chips")
local header = require("atlas.bitbucket.ui.panel.components.header")
local spinner = require("atlas.ui.components.spinner")
local overview_tab = require("atlas.bitbucket.ui.panel.repository.tabs.overview")
local branches_tab = require("atlas.bitbucket.ui.panel.repository.tabs.branches")
local tags_tab = require("atlas.bitbucket.ui.panel.repository.tabs.tags")

local ns = vim.api.nvim_create_namespace("atlas.bitbucket.panel")
local PADDING_X = 2

local function pad_line(line)
	local pad = string.rep(" ", PADDING_X)
	return pad .. (line or "") .. pad
end

---@param tab "overview"|"branches"|"tags"
---@param repo table
---@param detail BitbucketRepositoryDetail|nil
---@param width integer|nil
---@return string[]
---@return table[]
local function render_tab_content(tab, repo, detail, width)
	if tab == "overview" then
		return overview_tab.render()
	end
	if tab == "branches" then
		return branches_tab.render(repo, detail, width)
	end

	return tags_tab.render(repo, detail, width)
end

---@param repo table
---@param width integer|nil
---@return string[]
---@return table[]
local function repo_lines(repo, width)
	local full_width = math.max((width or 1), 1)
	local content_width = math.max(full_width - (PADDING_X * 2), 1)
	local tab = state.current_tab or "overview"
	local tabs_line, tabs_spans = tabs.render_repo(tab)
	local detail = state.current_detail

	if detail == "loading" then
		local loading_line = spinner.with_text("Loading...")
		local rows = { pad_line(loading_line), pad_line(""), pad_line(tabs_line), pad_line("") }
		local spans = {
			{ line = 0, start_col = PADDING_X, end_col = PADDING_X + #loading_line, hl_group = "AtlasTextMuted" },
		}
		for _, span in ipairs(tabs_spans or {}) do
			table.insert(spans, {
				line = 2,
				start_col = span.start_col + PADDING_X,
				end_col = span.end_col + PADDING_X,
				hl_group = span.hl_group,
			})
		end

		local body_lines, body_spans = render_tab_content(tab, repo, nil, content_width)
		local body_base = #rows
		for _, line in ipairs(body_lines or {}) do
			table.insert(rows, pad_line(line))
		end
		for _, span in ipairs(body_spans or {}) do
			table.insert(spans, {
				line = body_base + span.line,
				start_col = span.start_col + PADDING_X,
				end_col = span.end_col + PADDING_X,
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
	local header_lines, header_spans = header.render_repo(repo, header_detail, content_width)

	local rows = {}
	local out_spans = {}

	local header_base = #rows
	for _, line in ipairs(header_lines or {}) do
		table.insert(rows, pad_line(line))
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
				start_col = span.start_col + PADDING_X,
				end_col = span.end_col + PADDING_X,
				hl_group = span.hl_group,
			})
		end
	end

	table.insert(rows, pad_line(""))
	local chips_line_idx = #rows
	table.insert(rows, pad_line(chips_line))
	table.insert(rows, pad_line(""))
	local tabs_line_idx = #rows
	table.insert(rows, pad_line(tabs_line))
	local rule_line_idx = #rows
	table.insert(rows, string.rep("─", full_width))
	table.insert(rows, pad_line(""))

	for _, span in ipairs(chips_spans or {}) do
		table.insert(out_spans, {
			line = chips_line_idx,
			start_col = span.start_col + PADDING_X,
			end_col = span.end_col + PADDING_X,
			hl_group = span.hl_group,
		})
	end
	for _, span in ipairs(tabs_spans or {}) do
		table.insert(out_spans, {
			line = tabs_line_idx,
			start_col = span.start_col + PADDING_X,
			end_col = span.end_col + PADDING_X,
			hl_group = span.hl_group,
		})
	end
	table.insert(out_spans, {
		line = rule_line_idx,
		start_col = 0,
		end_col = #(rows[rule_line_idx + 1] or ""),
		hl_group = "AtlasTextMuted",
	})

	local detail_table = type(detail) == "table" and detail or nil
	local body_lines, body_spans = render_tab_content(tab, repo, detail_table, content_width)
	local body_base = #rows
	for _, line in ipairs(body_lines or {}) do
		table.insert(rows, pad_line(line))
	end
	for _, span in ipairs(body_spans or {}) do
		table.insert(out_spans, {
			line = body_base + span.line,
			start_col = span.start_col + PADDING_X,
			end_col = span.end_col + PADDING_X,
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
	local out_lines, spans = repo_lines(repo, width)

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
			local start_col = math.max(0, math.min((tonumber(span.start_col) or 0), line_len))
			local end_col = math.max(start_col, math.min((tonumber(span.end_col) or 0), line_len))

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
