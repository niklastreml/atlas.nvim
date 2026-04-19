local M = {}

local pr_panel = require("atlas.pulls.ui.panel.pr")
local repo_panel = require("atlas.pulls.ui.panel.repo")
local panel_state = require("atlas.pulls.ui.panel.state")

---@return table
local function active_panel()
	if panel_state.current_panel == "repo" then
		return repo_panel
	end
	return pr_panel
	end

function M.is_open()
	return active_panel().is_open()
end

function M.render()
	return active_panel().render()
end

function M.on_select(pr, repo, opts)
	if panel_state.current_panel == "repo" then
		return repo_panel.on_select(repo, opts)
	end
	return pr_panel.on_select(pr, repo, opts)
end

function M.next_tab()
	return active_panel().next_tab()
end

function M.prev_tab()
	return active_panel().prev_tab()
end

function M.close()
	panel_state.reset()
	return active_panel().close()
end

return M
