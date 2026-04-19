---@class PullsRepoBranchesTab : PullsRepoPanelTabModule
local M = {}

local utils = require("atlas.ui.shared.utils")
local icons = require("atlas.ui.shared.icons")
local spinner = require("atlas.ui.components.spinner")
local threads = require("atlas.ui.components.threadsv2")
local state = require("atlas.pulls.ui.panel.repo.tabs.branches.state")
local repo_panel_state = require("atlas.pulls.ui.panel.repo.state")

local PADDING_X = 1

---@type { cancel: fun() }|nil
local request = nil

local function stop_request()
	if request ~= nil then
		request.cancel()
		request = nil
	end
end

---@param repo PullsRepoDetails
---@return AtlasThreadV2Item[]
local function to_items(repo)
	local items = {}
	for _, branch in ipairs((state.branches or {}).entries or {}) do
		table.insert(items, {
			icon = icons.pulls("branch"),
			author = tostring(branch.name or ""),
			additional = tostring(branch.author or ""),
			right_text = utils.relative_time_text(branch.date),
			content = tostring((branch.message or ""):match("^[^\n\r]*") or ""),
			obj = { repo = repo, branch = branch },
		})
	end
	return items
end

---@param _repo PullsRepo
---@param width integer
---@return string[], table[], table<integer, table>
function M.render(_repo, width)
	local lines = {}
	local spans = {}
	local line_map = {}

	if state.branches == nil then
		if repo_panel_state.current_repo_details == "loading" then
			utils.push(lines, spans, spinner.with_text("Loading repository details..."), "AtlasTextMuted", PADDING_X)
		end
		return lines, spans, line_map
	end

	if state.branches == "loading" then
		utils.push(lines, spans, spinner.with_text("Loading branches..."), "AtlasTextMuted", PADDING_X)
		return lines, spans, line_map
	end

	local repo = state.repo
	if repo == nil then
		utils.push(lines, spans, "No branches loaded.", "AtlasTextMuted", PADDING_X)
		return lines, spans, line_map
	end

	local entries = state.branches.entries or {}
	if #entries == 0 then
		utils.push(lines, spans, "No branches found.", "AtlasTextMuted", PADDING_X)
		return lines, spans, line_map
	end

	local thread_lines, thread_spans, thread_map = threads.render(to_items(repo), width, {
		padding_x = PADDING_X,
		mode = "linked",
		right_text_align = "right",
		content_max_lines = 1,
		author_hl = function()
			return "AtlasText"
		end,
		content_hl = function(_, row)
			return { { start_col = 0, end_col = #row, hl_group = "AtlasTextMuted" } }
		end,
	})

	utils.append_block(lines, spans, { lines = thread_lines, highlights = thread_spans })
	line_map = thread_map or {}
	state.line_map = line_map
	return lines, spans, line_map
end

---@param _pr PullRequest|nil
---@param repo PullsRepo|nil
---@param done fun()
---@param opts PullsFetchOpts|nil
function M.on_select(_pr, repo, done, opts)
	opts = opts or {}
	local detail = require("atlas.pulls.ui.panel.repo.state").current_repo_details
	if detail == nil or repo == nil then
		state.reset()
		done()
		return
	end

	local prev_name = state.repo and state.repo.full_name or ""
	local next_name = tostring(detail.full_name or "")
	local should_fetch = opts.force_refresh == true or state.branches == nil or prev_name ~= next_name
	state.repo = detail
	if not should_fetch then
		done()
		return
	end

	stop_request()
	state.branches = "loading"
	done()

	local provider = require("atlas.pulls.state").provider
	if provider == nil or type(provider.fetch_repo_branches) ~= "function" then
		state.branches = { entries = {} }
		done()
		return
	end

	request = provider.fetch_repo_branches(detail, opts, function(branches, err)
		request = nil
		local active_detail = require("atlas.pulls.ui.panel.repo.state").current_repo_details
		if active_detail == nil or tostring(active_detail.full_name or "") ~= next_name then
			return
		end
		state.repo = active_detail
		state.branches = err == nil and (branches or { entries = {} }) or { entries = {} }
		done()
	end)
end

function M.deactivate()
	stop_request()
end

---@return boolean
function M.is_loading()
	return state.branches == "loading"
end

return M
