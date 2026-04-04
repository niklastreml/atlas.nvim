local M = {}
local state = require("atlas.jira.panel.tabs.comments.state")
local panel_state = require("atlas.jira.panel.state")
local jira_state = require("atlas.jira.state")
local spinner = require("atlas.ui.components.spinner")
local footer = require("atlas.ui.components.footer")
local comments_api = require("atlas.jira.api.comments")
local helper = require("atlas.jira.panel.tabs.comments.helper")
local markdown_editor = require("atlas.jira.ui.markdown_editor")

local active_handle = nil
local COMMENTS_PAGE_SIZE = 20

---@return integer|nil
local function detail_win()
	local layout = require("atlas.ui.layout")
	local win = layout.win_id("detail")
	if win == nil or not vim.api.nvim_win_is_valid(win) then
		return nil
	end
	return win
end

---@param lnum integer
---@return boolean
local function is_comment_line(lnum)
	local item = (state.line_map or {})[lnum]
	if type(item) ~= "table" or type(item.comment) ~= "table" then
		return false
	end

	return item.kind == "content" or item.kind == "thread_content"
end

---@return JiraComment|nil
local function current_comment_under_cursor()
	local win = detail_win()
	if win == nil then
		return nil
	end

	local line = vim.api.nvim_win_get_cursor(win)[1]
	local item = (state.line_map or {})[line]
	if type(item) ~= "table" then
		return nil
	end

	if item.kind ~= "content" and item.kind ~= "thread_content" then
		return nil
	end

	if type(item.comment) ~= "table" then
		return nil
	end

	return item.comment
end

---@param win integer
---@param delta integer
---@return boolean
local function jump_next_comment(win, delta)
	local line = vim.api.nvim_win_get_cursor(win)[1]
	local buf = vim.api.nvim_win_get_buf(win)
	local max_line = vim.api.nvim_buf_line_count(buf)
	local step = delta > 0 and 1 or -1

	for lnum = line + step, (step > 0 and max_line or 1), step do
		if is_comment_line(lnum) then
			vim.api.nvim_win_set_cursor(win, { lnum, 0 })
			return true
		end
	end

	return false
end

---@param delta integer
function M.move(delta)
	if panel_state.current_tab ~= "comments" then
		return
	end

	local win = detail_win()
	if win == nil then
		return
	end

	local buf = vim.api.nvim_win_get_buf(win)
	local max_line = vim.api.nvim_buf_line_count(buf)

	if delta == 0 then
		for lnum = 1, max_line do
			if is_comment_line(lnum) then
				vim.api.nvim_win_set_cursor(win, { lnum, 0 })
				return
			end
		end
		return
	end
	if delta == math.huge then
		for lnum = max_line, 1, -1 do
			if is_comment_line(lnum) then
				vim.api.nvim_win_set_cursor(win, { lnum, 0 })
				return
			end
		end
		return
	end

	if jump_next_comment(win, delta) then
		return
	end

	local line = vim.api.nvim_win_get_cursor(win)[1]
	local step = delta > 0 and 1 or -1
	local target = math.max(1, math.min(max_line, line + step))
	vim.api.nvim_win_set_cursor(win, { target, 0 })
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
			state.comments = helper.normalize_comments(state.comments, { include_deleted_parents = false })
			require("atlas.jira.panel.init").refresh()
			M.move(0)

			local loaded = #state.comments
			local total = (page and page.total) or loaded
			if loaded < total then
				fetch_next(loaded)
				return
			end

			state.comments = helper.normalize_comments(state.comments)

			state.state = nil
			stop_spinner()
			footer.notify("success", string.format("Comments loaded for %s (%d)", issue.key, loaded), 1200)
			require("atlas.jira.panel.init").refresh()
			M.move(0)
		end)
	end

	fetch_next(0)
end

function M.refresh()
	if state.issue == nil then
		return
	end

	cancel_active()
	stop_spinner()
	state.comments = nil
	state.state = nil
	M.show(state.issue)
end

function M.reset()
	cancel_active()
	stop_spinner()
	state.reset()
end

function M.deactivate()
	stop_spinner()
end

function M.add_comment()
	local issue = state.issue
	if issue == nil or type(issue.key) ~= "string" or issue.key == "" then
		footer.notify("warn", "No issue selected")
		return
	end

	markdown_editor.open({
		key = string.format("comment-add-%s", issue.key),
		title = string.format("Add Comment %s", issue.key),
		initial_text = "",
		width_ratio = 0.65,
		height_ratio = 0.65,
		on_save = function(body)
			if vim.trim(body) == "" then
				footer.notify("warn", "Comment cannot be empty")
				return
			end

			footer.notify("loading", "Adding comment...")
			comments_api.add_comment(issue.key, body, function(comment, err)
				if err ~= nil then
					footer.notify("error", err)
					return
				end

				if type(state.comments) ~= "table" then
					state.comments = {}
				end

				if type(comment) == "table" then
					table.insert(state.comments, comment)
				end

				state.comments = helper.normalize_comments(state.comments)

				require("atlas.jira.panel.init").refresh()
				M.move(0)
				footer.notify("success", "Comment added", 1200)
			end)
		end,
		on_cancel = function()
			footer.notify("info", "Add comment cancelled")
		end,
	})
end

function M.reply_to_comment()
	local issue = state.issue
	if issue == nil or type(issue.key) ~= "string" or issue.key == "" then
		footer.notify("warn", "No issue selected")
		return
	end

	local parent = current_comment_under_cursor()
	if parent == nil then
		footer.notify("warn", "No comment selected")
		return
	end

	local parent_id = tostring(parent.id or "")
	if parent_id == "" then
		footer.notify("warn", "Invalid parent comment")
		return
	end

	local parent_label = ((parent.author or {}).display_name and tostring((parent.author or {}).display_name) ~= "")
			and tostring((parent.author or {}).display_name)
		or "unknown user"

	vim.ui.input({
		prompt = string.format("Reply to %s: ", parent_label),
	}, function(input)
		if input == nil then
			footer.notify("info", "Reply cancelled")
			return
		end

		local body = tostring(input)
		if vim.trim(body) == "" then
			footer.notify("warn", "Reply cannot be empty")
			return
		end

		footer.notify("loading", string.format("Replying to %s...", parent_label))
		comments_api.add_comment(issue.key, body, { parent_id = parent_id }, function(comment, err)
			if err ~= nil then
				footer.notify("error", err)
				return
			end

			if type(state.comments) ~= "table" then
				state.comments = {}
			end

			if type(comment) == "table" then
				table.insert(state.comments, comment)
			end

			state.comments = helper.normalize_comments(state.comments)

			require("atlas.jira.panel.init").refresh()
			M.move(0)
			footer.notify("success", "Reply added", 1200)
		end)
	end)
end

function M.edit_comment()
	local issue = state.issue
	if issue == nil or type(issue.key) ~= "string" or issue.key == "" then
		footer.notify("warn", "No issue selected")
		return
	end

	local comment = current_comment_under_cursor()
	if comment == nil then
		footer.notify("warn", "No comment selected")
		return
	end

	if not helper.can_manage_comment(comment, jira_state.current_user) then
		footer.notify("warn", "You can only edit your own comments")
		return
	end

	local comment_id = tostring(comment.id or "")
	if comment_id == "" then
		footer.notify("warn", "Invalid comment id")
		return
	end

	local current_body = tostring(comment.body or "")

	markdown_editor.open({
		key = string.format("comment-%s-%s", issue.key, comment_id),
		title = string.format("Edit Comment %s", comment_id),
		initial_text = current_body,
		width_ratio = 0.65,
		height_ratio = 0.65,
		on_save = function(body)
			if vim.trim(body) == "" then
				footer.notify("warn", "Comment cannot be empty")
				return
			end

			footer.notify("loading", string.format("Updating comment %s...", comment_id))
			comments_api.edit_comment(issue.key, comment_id, body, function(updated_comment, err)
				if err ~= nil then
					footer.notify("error", err)
					return
				end

				state.comments = helper.remove_comment(state.comments, comment_id)
				if type(updated_comment) == "table" then
					table.insert(state.comments, updated_comment)
				end
				state.comments = helper.normalize_comments(state.comments)

				require("atlas.jira.panel.init").refresh()
				M.move(0)
				footer.notify("success", "Comment updated", 1200)
			end)
		end,
		on_cancel = function()
			footer.notify("info", "Edit cancelled")
		end,
	})
end

function M.delete_comment()
	local issue = state.issue

	local comment = current_comment_under_cursor()
	if comment == nil then
		footer.notify("warn", "No comment selected")
		return
	end

	if not helper.can_manage_comment(comment, jira_state.current_user) then
		footer.notify("warn", "You can only delete your own comments")
		return
	end

	if issue == nil or type(issue.key) ~= "string" or issue.key == "" then
		footer.notify("warn", "No issue selected")
		return
	end

	local comment_id = tostring(comment.id or "")
	if comment_id == "" then
		footer.notify("warn", "Invalid comment id")
		return
	end

	local comment_label = ((comment.author or {}).display_name and tostring((comment.author or {}).display_name) ~= "")
			and tostring((comment.author or {}).display_name)
		or "unknown user"

	vim.ui.input({
		prompt = string.format("Delete comment(%s) by %s? [y/N]: ", comment_id, comment_label),
	}, function(input)
		if input == nil then
			footer.notify("info", "Delete cancelled")
			return
		end

		local normalized = vim.trim(tostring(input)):lower()
		if normalized ~= "y" and normalized ~= "yes" then
			footer.notify("info", "Delete cancelled")
			return
		end

		footer.notify("loading", string.format("Deleting comment %s...", comment_id))
		comments_api.delete_comment(issue.key, comment_id, function(ok, err)
			if not ok then
				footer.notify("error", err or "Failed to delete comment")
				return
			end

			state.comments = helper.remove_comment(state.comments, comment_id)
			state.comments = helper.normalize_comments(state.comments)

			require("atlas.jira.panel.init").refresh()
			M.move(0)
			footer.notify("success", "Comment deleted", 1200)
		end)
	end)
end

return M
