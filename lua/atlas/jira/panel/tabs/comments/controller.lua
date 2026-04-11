local M = {}
local state = require("atlas.jira.panel.tabs.comments.state")
local panel_state = require("atlas.jira.panel.state")
local jira_state = require("atlas.jira.state")
local footer = require("atlas.ui.components.footer")
local comments_api = require("atlas.jira.api.comments")
local helper = require("atlas.jira.panel.tabs.comments.helper")
local markdown_editor = require("atlas.jira.ui.markdown_editor")

local active_handle = nil
local COMMENTS_PAGE_SIZE = 20
local MAX_COMMENT_PAGES = 5

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
	local item = state.line_map[lnum]
	if item == nil or item.comment == nil then
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
	local item = state.line_map[line]
	if item == nil then
		return nil
	end
	if item.kind ~= "content" and item.kind ~= "thread_content" then
		return nil
	end
	if item.comment == nil then
		return nil
	end
	return item.comment
end

---@param comment_id string
---@return JiraComment|nil
local function find_comment_by_id(comment_id)
	if comment_id == "" or state.comments == nil then
		return nil
	end
	for _, comment in ipairs(state.comments) do
		if comment.id == comment_id then
			return comment
		end
	end
	return nil
end

---@param user JiraUser|nil
---@return string
local function mention_prefix_for_user(user)
	if user == nil or user.account_id == "" or user.display_name == "" then
		return ""
	end
	return string.format("[@%s]{mention:%s} ", user.display_name, user.account_id)
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

local function cancel_active()
	if active_handle ~= nil and active_handle.cancel then
		pcall(active_handle.cancel)
	end
	active_handle = nil
end

---@param issue JiraIssue|nil
---@param opts? { force_refresh?: boolean }
function M.show(issue, opts)
	opts = opts or {}
	local force_refresh = opts.force_refresh == true
	local current_key = state.issue and state.issue.key or nil
	local next_key = issue and issue.key or nil

	if force_refresh or current_key ~= next_key then
		cancel_active()
	end

	if not force_refresh and current_key == next_key and state.state == "loading" then
		state.issue = issue
		state.line_map = {}
		require("atlas.jira.panel.init").refresh()
		return
	end

	state.issue = issue
	state.line_map = {}

	if issue == nil or issue.key == "" then
		state.comments = nil
		state.state = nil
		return
	end

	if not force_refresh and current_key == next_key and state.state ~= "loading" and state.comments ~= nil then
		return
	end

	state.comments = {}
	state.state = "loading"
	footer.notify("loading", string.format("Loading comments for %s...", issue.key))
	require("atlas.jira.panel.init").refresh()

	local function fetch_next(start_at, page_count)
		page_count = page_count or 1
		active_handle = comments_api.get_comments_page(issue.key, start_at, COMMENTS_PAGE_SIZE, function(page, err)
			active_handle = nil

			if state.issue == nil or state.issue.key ~= issue.key then
				return
			end

			if err ~= nil then
				state.state = nil
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
			if loaded < total and page_count < MAX_COMMENT_PAGES then
				fetch_next(loaded, page_count + 1)
				return
			end

			state.comments = helper.normalize_comments(state.comments)
			state.state = nil
			if loaded < total then
				footer.notify("warn", string.format("Comments partial (%d/%d)", loaded, total), 1800)
			else
				footer.notify("success", string.format("Comments loaded for %s (%d)", issue.key, loaded), 1200)
			end

			require("atlas.jira.panel.init").refresh()
			M.move(0)
		end, { force_load = force_refresh })
	end

	fetch_next(0, 1)
end

function M.refresh()
	if state.issue == nil then
		return
	end

	M.show(state.issue, { force_refresh = true })
end

function M.reset()
	cancel_active()
	state.reset()
end

function M.deactivate() end

---@return boolean
function M.is_loading()
	return state.state == "loading"
end

function M.add_comment()
	local issue = state.issue
	if issue == nil or issue.key == "" then
		footer.notify("warn", "No issue selected")
		return
	end

	markdown_editor.open({
		key = string.format("comment-add-%s", issue.key),
		title = string.format("Add Comment %s", issue.key),
		initial_text = "",

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

				if state.comments == nil then
					state.comments = {}
				end
				if comment ~= nil then
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
	if issue == nil or issue.key == "" then
		footer.notify("warn", "No issue selected")
		return
	end

	local parent = current_comment_under_cursor()
	if parent == nil then
		footer.notify("warn", "No comment selected")
		return
	end

	--- We cant reply to a subcomment, so we need to find the top level parent comment to reply to. Jira API only supports one level of nesting, so all replies are added as children of the top level comment.
	local parent_id = parent.id
	if parent.parent_id ~= nil then
		local maybe_parent = tostring(parent.parent_id)
		if maybe_parent ~= "" then
			parent_id = maybe_parent
		end
	end
	if parent_id == "" then
		footer.notify("warn", "Invalid parent comment")
		return
	end

	local reply_target = find_comment_by_id(parent_id) or parent
	local parent_label = (reply_target.author ~= nil and reply_target.author.display_name ~= "")
			and reply_target.author.display_name
		or "unknown user"
	local initial_text = mention_prefix_for_user(reply_target.author)

	vim.ui.input({
		prompt = string.format("Reply to %s: ", parent_label),
		default = initial_text,
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

			if state.comments == nil then
				state.comments = {}
			end
			if comment ~= nil then
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
	if issue == nil or issue.key == "" then
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

	local comment_id = comment.id
	if comment_id == "" then
		footer.notify("warn", "Invalid comment id")
		return
	end

	local current_body = comment.body

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
				if updated_comment ~= nil then
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
	if issue == nil or issue.key == "" then
		footer.notify("warn", "No issue selected")
		return
	end

	local comment = current_comment_under_cursor()
	if comment == nil then
		footer.notify("warn", "No comment selected")
		return
	end

	if not helper.can_manage_comment(comment, jira_state.current_user) then
		footer.notify("warn", "You can only delete your own comments")
		return
	end

	local comment_id = comment.id
	if comment_id == "" then
		footer.notify("warn", "Invalid comment id")
		return
	end

	local comment_label = (comment.author ~= nil and comment.author.display_name ~= "") and comment.author.display_name
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
