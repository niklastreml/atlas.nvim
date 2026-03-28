local M = {}

local layout = require("atlas.ui.layout")
local state = require("atlas.bitbucket.ui.panel.state")

local function lines_for_pr(pr)
	if pr == nil then
		return {
			"Bitbucket PR Details",
			"",
			"No PR selected.",
		}
	end

	local author = (pr.author and pr.author.name) or "-"
	return {
		"Bitbucket PR Details",
		"",
		string.format("#%s %s", tostring(pr.id or "?"), tostring(pr.title or "")),
		"",
		"Author: " .. author,
		"State: " .. tostring(pr.state or "-"),
		"Draft: " .. ((pr.is_draft and "yes") or "no"),
		"Source: " .. tostring(pr.source_branch or "-"),
		"Target: " .. tostring(pr.target_branch or "-"),
		"Comments: " .. tostring(pr.comments or 0),
		"Tasks: " .. tostring(pr.tasks or 0),
	}
end

function M.render()
	local buf = layout.detail_buf_id()
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines_for_pr(state.current_pr))
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
end

return M
