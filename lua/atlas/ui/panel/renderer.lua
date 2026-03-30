local M = {}
local state = require("atlas.ui.panel.state")

---@param provider "bitbucket"|"jira"
function M.render(provider)
	if provider == "bitbucket" then
		local item = state.selected_item
		if type(item) == "table" and item.kind == "repo" then
			require("atlas.bitbucket.ui.panel.repository.controller").refresh()
		else
			require("atlas.bitbucket.ui.panel.prs.controller").refresh()
		end
		return
	end

	local layout = require("atlas.ui.layout")
	local buf = layout.buf_id("detail")
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
		"Panel",
		"",
		"No renderer yet for provider: " .. tostring(provider),
	})
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
end

return M
