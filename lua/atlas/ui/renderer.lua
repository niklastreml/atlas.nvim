local M = {}

local state = require("atlas.ui.state")
local utils = require("atlas.utils")
local footer = require("atlas.ui.components.footer")

local ns = vim.api.nvim_create_namespace("atlas.ui")

local function apply_spans(buf, spans)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	for _, span in ipairs(spans) do
		vim.api.nvim_buf_set_extmark(buf, ns, span.line, span.start_col, {
			end_row = span.line,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end
end

---@param view "bitbucket"|"github"|"jira"
---@param opts { force_refresh?: boolean, autofocus?: boolean }|nil
function M.render(view, opts)
	local lines = {}
	local spans = {}
	local line_map = {}

	local target_view = view or state.current_view or "jira"
	local width = vim.api.nvim_win_get_width(state.win_id)
	local height = vim.api.nvim_win_get_height(state.win_id)

	if target_view == "jira" then
		state.current_view = "jira"
		lines, spans, line_map = require("atlas.jira.ui.renderer").render({ width = width, height = height })
	elseif target_view == "bitbucket" then
		state.current_view = "bitbucket"
		local bitbucket_state = require("atlas.bitbucket.state")
		if opts and opts.force_refresh then
			require("atlas.bitbucket.actions").refresh_current_view(function()
				if opts and opts.autofocus then
					require("atlas.ui.navigation").focus_first_item()
				end
			end)
		elseif not bitbucket_state.is_loading and bitbucket_state.repos == nil and bitbucket_state.error == nil then
			require("atlas.bitbucket.actions").refresh_current_view(function()
				if opts and opts.autofocus then
					require("atlas.ui.navigation").focus_first_item()
				end
			end)
		end

		lines, spans, line_map = require("atlas.bitbucket.ui.renderer").render({ width = width, height = height })
	elseif target_view == "github" then
		state.current_view = "github"
		lines, spans, line_map = require("atlas.github.ui.renderer").render({ width = width, height = height })
	end

	local buf = state.buf_id
	state.line_map = line_map or {}

	local footer_block = footer.render({
		width = width,
		segments = footer.segments_for(target_view),
	})

	local footer_rows = #footer_block.lines
	local max_content_rows = math.max(height - footer_rows, 0)
	local fill = max_content_rows - #lines

	if fill > 0 then
		for _ = 1, fill do
			table.insert(lines, "")
		end
	end

	utils.append_block(lines, spans, footer_block)

	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or {})
	apply_spans(buf, spans)
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

	if opts and opts.autofocus then
		require("atlas.ui.navigation").focus_first_item()
	end
end

local resize_group = vim.api.nvim_create_augroup("AtlasUIResize", { clear = true })
vim.api.nvim_create_autocmd({ "VimResized", "WinResized" }, {
	group = resize_group,
	callback = function()
		local window = require("atlas.ui.window")
		if window.is_open() then
			M.render(state.current_view)
		end
	end,
})

return M
