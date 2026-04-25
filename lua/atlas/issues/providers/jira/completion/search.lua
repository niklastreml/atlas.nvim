local M = {}

local controller = require("atlas.issues.ui.main.controller")
local footer = require("atlas.ui.components.footer")
local navigation = require("atlas.ui.navigation")
local jql_api = require("atlas.issues.providers.jira.completion.jql")
local layout = require("atlas.ui.layout")
local ui_state = require("atlas.ui.state")
local autocomplete_fetch_started = false

local function is_issues_open()
	return layout.is_open() and ui_state.current_view == "jira"
end

---@param query string
---@return boolean, string|nil
function M.run(query)
	local text = vim.trim(tostring(query or ""))
	if text == "" then
		return false, "Search query cannot be empty"
	end

	local search_view = {
		name = "Search (JQL)",
		jql = text,
	}

	if is_issues_open() then
		controller.switch_view(search_view)
	else
		require("atlas").open("issues", "jira", { initial_view = search_view })
		vim.schedule(function()
			navigation.focus_first_item()
		end)
	end

	return true, nil
end

---@param opts { args: string }
function M.command(opts)
	local ok, err = M.run(opts.args or "")
	if not ok then
		vim.notify(err or "Invalid query", vim.log.levels.WARN)
		footer.notify("warn", err or "Invalid query")
	end
end

---@param arglead string
---@param cmdline string
---@param cursorpos integer
---@return string[]
function M.complete(arglead, cmdline, cursorpos)
	if not autocomplete_fetch_started then
		autocomplete_fetch_started = true
		jql_api.get_autocomplete_data(function() end, { force_load = false })
	end

	return jql_api.complete_cmdline(arglead, cmdline, cursorpos)
end

function M.open_cmdline()
	local keys = vim.api.nvim_replace_termcodes(":AtlasJqlSearch ", true, false, true)
	vim.schedule(function()
		vim.api.nvim_feedkeys(keys, "n", false)
	end)
end

return M
