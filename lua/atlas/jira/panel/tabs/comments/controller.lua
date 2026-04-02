local M = {}
local state = require("atlas.jira.panel.tabs.comments.state")
local panel_state = require("atlas.jira.panel.state")
local spinner = require("atlas.ui.components.spinner")
local footer = require("atlas.ui.components.footer")
local comments_api = require("atlas.jira.api.comments")

local active_handle = nil
local COMMENTS_PAGE_SIZE = 1

---@param comments JiraComment[]|nil
local function sort_comments_by_created(comments)
	if type(comments) ~= "table" then
		return
	end

	table.sort(comments, function(a, b)
		local ac = tostring((a and a.created) or "")
		local bc = tostring((b and b.created) or "")
		if ac == bc then
			return tostring((a and a.id) or "") < tostring((b and b.id) or "")
		end
		return ac > bc
	end)
end

---@param comments JiraComment[]|nil
local function sort_comment_children(comments)
	if type(comments) ~= "table" then
		return
	end

	for _, comment in ipairs(comments) do
		if type(comment) == "table" and type(comment.children) == "table" and #comment.children > 0 then
			table.sort(comment.children, function(a, b)
				local ac = tostring((a and a.created) or "")
				local bc = tostring((b and b.created) or "")
				if ac == bc then
					return tostring((a and a.id) or "") < tostring((b and b.id) or "")
				end
				return ac < bc
			end)
			sort_comment_children(comment.children)
		end
	end
end

---@param comments JiraComment[]|nil
local function rebuild_comment_tree(comments)
	if type(comments) ~= "table" then
		return
	end

	local by_id = {}
	for _, comment in ipairs(comments) do
		if type(comment) == "table" then
			comment.children = {}
			by_id[tostring(comment.id or "")] = comment
		end
	end

	for _, comment in ipairs(comments) do
		if type(comment) == "table" and comment.parent_id ~= nil then
			local parent = by_id[tostring(comment.parent_id)]
			if parent ~= nil then
				table.insert(parent.children, comment)
			end
		end
	end

	sort_comment_children(comments)
end

local panel_spinner = spinner.create({
	interval_ms = 120,
	on_tick = function()
		if state.state ~= "loading" then
			panel_spinner:stop()
			return
		end
		if panel_state.current_tab ~= "comments" then
			return
		end
		require("atlas.jira.panel.init").refresh()
	end,
})

local function stop_spinner()
	panel_spinner:stop()
end

local function cancel_active()
	if active_handle ~= nil and active_handle.cancel then
		pcall(active_handle.cancel)
	end
	active_handle = nil
end

local function start_spinner()
	if panel_spinner:is_running() then
		return
	end
	panel_spinner:start()
end

---@param issue JiraIssue|nil
function M.show(issue)
	local prev_key = state.issue and state.issue.key or nil
	local next_key = issue and issue.key or nil
	local same_issue = prev_key == next_key

	if same_issue and state.state == "loading" then
		state.issue = issue
		state.line_map = {}
		start_spinner()
		require("atlas.jira.panel.init").refresh()
		return
	end

	stop_spinner()
	state.issue = issue
	state.line_map = {}

	if issue == nil or issue.key == "" then
		cancel_active()
		state.comments = nil
		state.state = nil
		return
	end

	if same_issue and state.state ~= "loading" and state.comments ~= nil then
		return
	end

	state.comments = {}
	state.state = "loading"
	start_spinner()
	footer.notify("loading", string.format("Loading comments for %s...", issue.key))
	require("atlas.jira.panel.init").refresh()

	if not same_issue then
		cancel_active()
	end

	local function fetch_next(start_at)
		active_handle = comments_api.get_comments_page(issue.key, start_at, COMMENTS_PAGE_SIZE, function(page, err)
			active_handle = nil

			if state.issue == nil or state.issue.key ~= issue.key then
				return
			end

			if err ~= nil then
				state.state = nil
				stop_spinner()
				footer.notify("error", string.format("Failed loading comments for %s", issue.key))
				require("atlas.jira.panel.init").refresh()
				return
			end

			for _, comment in ipairs((page and page.comments) or {}) do
				table.insert(state.comments, comment)
			end
			sort_comments_by_created(state.comments)
			rebuild_comment_tree(state.comments)
			require("atlas.jira.panel.init").refresh()

			local loaded = #state.comments
			local total = (page and page.total) or loaded
			if loaded < total then
				fetch_next(loaded)
				return
			end

			state.state = nil
			stop_spinner()
			footer.notify("success", string.format("Comments loaded for %s (%d)", issue.key, loaded), 1200)
			require("atlas.jira.panel.init").refresh()
		end)
	end

	fetch_next(0)
end

--- TODO: Add refresh keymap
function M.refresh() end

function M.reset()
	cancel_active()
	stop_spinner()
	state.reset()
end

function M.deactivate()
	stop_spinner()
end

function M.add_comment() end

function M.edit_comment_under_cursor() end

function M.delete_comment_under_cursor() end

return M
