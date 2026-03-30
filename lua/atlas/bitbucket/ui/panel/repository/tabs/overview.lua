local M = {}
local utils = require("atlas.utils")
local spinner = require("atlas.ui.components.spinner")

---@return string[]
---@return table[]
function M.render()
	local repo_state = require("atlas.bitbucket.ui.panel.repository.state")

	local readme = repo_state.current_readme
	if type(readme) == "string" and readme ~= "" and readme ~= "loading" then
		return utils.sanitize_markdown_lines(readme), {}
	end

	local line = spinner.with_text("Loading readme...")
	return { line }, {
		{ line = 0, start_col = 0, end_col = #line, hl_group = "AtlasTextMuted" },
	}
end

return M
