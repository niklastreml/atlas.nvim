local M = {}
local state = require("atlas.bitbucket.panel.tabs.pr.comments.state")
local comments_api = require("atlas.bitbucket.api.comments")
local helper = require("atlas.bitbucket.panel.tabs.pr.comments.helper")
local mention_completions = require("atlas.bitbucket.completion.author")
local footer = require("atlas.ui.components.footer")
local bitbucket_state = require("atlas.bitbucket.state")
local markdown_editor = require("atlas.ui.popups.markdown_editor")

local active_handle = nil
local tasks_handle = nil

---@param task BitbucketPRTask|nil
local function upsert_local_task(task)
	if type(task) ~= "table" then
		return
	end
	if state.tasks == "loading" then
		return
	end
	if type(state.tasks) ~= "table" then
		return
	end

	local target_id = tonumber(task.id)
	if target_id == nil then
		return
	end

	for i, entry in ipairs(state.tasks) do
		if type(entry) == "table" and tonumber(entry.id) == target_id then
			state.tasks[i] = task
			return
		end
	end
end

---@return integer|nil
local function detail_win()
	local layout = require("atlas.ui.layout")
	local win = layout.win_id("detail")
	if win == nil or not vim.api.nvim_win_is_valid(win) then
		return nil
	end
	return win
end

---@return BitbucketPRCommentEntry|nil
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
	if item.entity_kind ~= "comment" then
		return nil
	end
	if
		item.kind ~= "header"
		and item.kind ~= "thread_header"
		and item.kind ~= "content"
		and item.kind ~= "thread_content"
	then
		return nil
	end
	if item.comment == nil then
		return nil
	end
	return item.comment
end

---@return BitbucketPRTask|nil
local function current_task_under_cursor()
	local win = detail_win()
	if win == nil then
		return nil
	end

	local line = vim.api.nvim_win_get_cursor(win)[1]
	local item = state.line_map[line]
	if item == nil then
		return nil
	end
	if item.entity_kind ~= "task" then
		return nil
	end
	if
		item.kind ~= "header"
		and item.kind ~= "thread_header"
		and item.kind ~= "content"
		and item.kind ~= "thread_content"
	then
		return nil
	end
	if item.task == nil then
		return nil
	end
	return item.task
end

---@return string|nil
local function current_comments_url()
	local pr = state.pr
	if pr == nil then
		return nil
	end

	local comments_url = tostring((pr.links or {}).comments or "")
	if comments_url == "" then
		return nil
	end

	return comments_url
end

---@param task BitbucketPRTask
local function toggle_task(task)
	local task_url = tostring((task.links or {}).self or "")
	if task_url == "" then
		footer.notify("error", "Missing task URL")
		return
	end

	local is_resolved = tostring(task.state or "") == "RESOLVED"
	local next_state = is_resolved and "UNRESOLVED" or "RESOLVED"
	footer.notify("loading", is_resolved and "Reopening task..." or "Resolving task...")
	comments_api.update_task(task_url, {
		state = next_state,
		content_raw = tostring(task.content_raw or ""),
	}, function(updated, err)
		if err ~= nil then
			footer.notify("error", tostring(err))
			return
		end

		if type(updated) == "table" then
			local next_task = updated
			next_task.state = next_state
			upsert_local_task(next_task)
			task.state = next_task.state
			task.updated_on = next_task.updated_on
			task.resolved_on = next_task.resolved_on
			task.content_raw = next_task.content_raw
		end

		footer.notify("success", is_resolved and "Task reopened" or "Task resolved", 1200)
		require("atlas.bitbucket.panel.init").refresh()
	end)
end

---@param task BitbucketPRTask
local function edit_task(task)
	if not helper.can_manage_task(task, bitbucket_state.current_user) then
		footer.notify("warn", "You can only edit your own tasks")
		return
	end

	local task_url = tostring((task.links or {}).self or "")
	if task_url == "" then
		footer.notify("error", "Missing task URL")
		return
	end

	markdown_editor.open({
		key = string.format("bitbucket-task-edit-%s", tostring(task.id or "")),
		title = "Edit Task",
		initial_text = tostring(task.content_raw or ""),
		width_ratio = 0.22,
		height_ratio = 0.22,
		completion = mention_completions.build_completion(),
		on_save = function(body)
			local final_body = tostring(body or "")
			if vim.trim(final_body) == "" then
				footer.notify("warn", "Task cannot be empty")
				return
			end

			footer.notify("loading", "Updating task...")
			comments_api.update_task(task_url, {
				state = tostring(task.state or "UNRESOLVED"),
				content_raw = final_body,
			}, function(updated, err)
				if err ~= nil then
					footer.notify("error", tostring(err))
					return
				end

				if type(updated) == "table" then
					local next_task = updated
					upsert_local_task(next_task)
					task.state = next_task.state
					task.updated_on = next_task.updated_on
					task.resolved_on = next_task.resolved_on
					task.content_raw = next_task.content_raw
				else
					task.content_raw = final_body
				end

				footer.notify("success", "Task updated", 1200)
				require("atlas.bitbucket.panel.init").refresh()
			end)
		end,
	})
end

---@param task BitbucketPRTask
local function delete_task(task)
	if not helper.can_manage_task(task, bitbucket_state.current_user) then
		footer.notify("warn", "You can only delete your own tasks")
		return
	end

	local task_url = tostring((task.links or {}).self or "")
	if task_url == "" then
		footer.notify("error", "Missing task URL")
		return
	end

	vim.ui.input({
		prompt = string.format("Delete task %s? [y/N]: ", tostring(task.id or "")),
	}, function(input)
		if input == nil then
			return
		end

		local normalized = vim.trim(tostring(input)):lower()
		if normalized ~= "y" and normalized ~= "yes" then
			return
		end

		footer.notify("loading", "Deleting task...")
		comments_api.delete_task(task_url, function(_, err)
			if err ~= nil then
				footer.notify("error", tostring(err))
				return
			end

			if state.tasks == "loading" then
				return
			end
			if type(state.tasks) == "table" then
				local target_id = tonumber(task.id)
				if target_id ~= nil then
					for i = #state.tasks, 1, -1 do
						local entry = state.tasks[i]
						if type(entry) == "table" and tonumber(entry.id) == target_id then
							table.remove(state.tasks, i)
						end
					end
				end
			end
			footer.notify("success", "Task deleted", 1200)
			require("atlas.bitbucket.panel.init").refresh()
		end)
	end)
end

---@param lnum integer
---@return boolean
local function is_comment_line(lnum)
	local item = state.line_map[lnum]
	if item == nil then
		return false
	end
	if item.entity_kind ~= "comment" and item.entity_kind ~= "task" then
		return false
	end
	return item.kind == "header"
		or item.kind == "thread_header"
		or item.kind == "content"
		or item.kind == "thread_content"
end

local function cancel_active_handle()
	if active_handle ~= nil and active_handle.cancel then
		pcall(active_handle.cancel)
	end
	active_handle = nil

	if tasks_handle ~= nil and tasks_handle.cancel then
		pcall(tasks_handle.cancel)
	end
	tasks_handle = nil
end

---@param pr BitbucketPR
---@param opts { force_load?: boolean, show_loading?: boolean, success_label?: "loaded"|"refreshed" }|nil
local function load_comments_and_tasks(pr, opts)
	opts = opts or {}

	local comments_url = tostring((pr.links or {}).comments or "")
	if comments_url == "" then
		state.comments = nil
		state.tasks = nil
		footer.notify("error", "Missing comments URL")
		return
	end

	cancel_active_handle()

	state.comments = "loading"
	state.tasks = "loading"
	if opts.show_loading == true then
		footer.notify("loading", "Loading comments...")
	end

	local expected_id = tostring(pr.id or "")
	active_handle = comments_api.fetch_comments(comments_url, {
		force_load = opts.force_load == true,
	}, function(comments, err)
		active_handle = nil

		local current = state.pr
		if current == nil or tostring(current.id or "") ~= expected_id then
			return
		end

		if err ~= nil then
			state.comments = nil
			footer.notify("error", "Failed to load comments")
		else
			state.comments = comments.entries
			local label = opts.success_label == "refreshed" and "refreshed" or "loaded"
			footer.notify("success", "Comments " .. label, 1200)
		end
	end)

	tasks_handle = comments_api.fetch_tasks(pr.workspace, pr.repo, pr.id, {
		force_load = opts.force_load == true,
	}, function(tasks, err)
		tasks_handle = nil

		local current = state.pr
		if current == nil or tostring(current.id or "") ~= expected_id then
			return
		end

		if err ~= nil then
			state.tasks = nil
			footer.notify("error", "Failed to load tasks")
		else
			state.tasks = tasks and tasks.entries or {}
		end
	end)
end

---@param pr BitbucketPR|nil
function M.show(pr)
	local prev_id = state.pr and state.pr.id or nil
	local next_id = pr and pr.id or nil
	local same_pr = prev_id == next_id

	if not same_pr then
		cancel_active_handle()
	end

	if same_pr and state.comments == "loading" then
		state.pr = pr
		state.line_map = {}
		return
	end

	state.pr = pr
	state.line_map = {}

	if pr == nil then
		state.comments = nil
		state.tasks = nil
		return
	end

	if
		same_pr
		and state.comments ~= nil
		and state.comments ~= "loading"
		and state.tasks ~= "loading"
		and state.tasks ~= nil
	then
		return
	end

	load_comments_and_tasks(pr, {
		force_load = false,
		show_loading = true,
		success_label = "loaded",
	})
end

---@param opts? { force_load?: boolean }
function M.refresh(opts)
	opts = opts or {}
	local pr = state.pr
	if pr == nil then
		return
	end

	load_comments_and_tasks(pr, {
		force_load = opts.force_load == true,
		success_label = "refreshed",
	})
end

function M.reset()
	cancel_active_handle()
	state.reset()
end

function M.deactivate() end

---@return boolean
function M.is_loading()
	return state.comments == "loading" or state.tasks == "loading"
end

---@param lnum integer
---@return boolean
function M.is_selectable_line(lnum)
	return is_comment_line(lnum)
end

---@return boolean
function M.open_current_line()
	local task = current_task_under_cursor()
	if task ~= nil then
		local task_url = tostring((task.links or {}).html or "")
		if task_url == "" then
			return false
		end
		vim.ui.open(task_url)
		return true
	end

	local comment = current_comment_under_cursor()
	if comment == nil then
		return false
	end

	local comment_url = tostring((comment.links or {}).html or "")
	if comment_url == "" then
		return false
	end

	vim.ui.open(comment_url)
	return true
end

function M.add_comment()
	local comments_url = current_comments_url()
	if comments_url == nil then
		footer.notify("error", "Missing comments URL")
		return
	end
	local pr_id = tostring((state.pr or {}).id or "")
	markdown_editor.open({
		key = string.format("bitbucket-comment-add-%s", pr_id),
		title = "Add Comment",
		initial_text = "",
		width_ratio = 0.22,
		height_ratio = 0.22,
		completion = mention_completions.build_completion(),
		on_save = function(body)
			local final_body = tostring(body or "")
			if vim.trim(final_body) == "" then
				footer.notify("warn", "Comment cannot be empty")
				return
			end

			footer.notify("loading", "Adding comment...")
			comments_api.create_comment(comments_url, final_body, nil, function(created, err)
				if err ~= nil then
					footer.notify("error", tostring(err))
					return
				end

				if state.comments ~= "loading" then
					if type(state.comments) ~= "table" then
						state.comments = {}
					end
					if type(created) == "table" then
						table.insert(state.comments, created)
					end
				end

				footer.notify("success", "Comment added", 1200)
				require("atlas.bitbucket.panel.init").refresh()
			end)
		end,
	})
end

function M.add_task()
	local pr = state.pr
	if pr == nil then
		footer.notify("warn", "No PR selected")
		return
	end

	local workspace = tostring(pr.workspace or "")
	local repo = tostring(pr.repo or "")
	local pr_id = tostring(pr.id or "")
	if workspace == "" or repo == "" or pr_id == "" then
		footer.notify("error", "Missing PR info")
		return
	end

	local selected_comment = current_comment_under_cursor()
	local comment_id = selected_comment and selected_comment.id or nil

	markdown_editor.open({
		key = string.format("bitbucket-task-add-%s", pr_id),
		title = "Add Task",
		initial_text = "",
		width_ratio = 0.22,
		height_ratio = 0.22,
		completion = mention_completions.build_completion(),
		on_save = function(body)
			local final_body = tostring(body or "")
			if vim.trim(final_body) == "" then
				footer.notify("warn", "Task cannot be empty")
				return
			end

			footer.notify("loading", "Adding task...")
			comments_api.create_task(workspace, repo, pr_id, final_body, {
				comment_id = comment_id,
			}, function(created, err)
				if err ~= nil then
					footer.notify("error", tostring(err))
					return
				end

				if state.tasks ~= "loading" then
					if type(state.tasks) ~= "table" then
						state.tasks = {}
					end
					if type(created) == "table" then
						table.insert(state.tasks, created)
					end
				end

				footer.notify("success", "Task added", 1200)
				require("atlas.bitbucket.panel.init").refresh()
			end)
		end,
	})
end

function M.reply_to_comment()
	local comment = current_comment_under_cursor()
	if comment == nil then
		footer.notify("warn", "No comment selected")
		return
	end

	local comments_url = current_comments_url()
	if comments_url == nil then
		footer.notify("error", "Missing comments URL")
		return
	end
	local author = comment.author or {}
	local mention_id = tostring(author.account_id or "")
	local mention_name = tostring(author.nickname or "")
	if mention_name == "" then
		mention_name = tostring(author.name or "")
	end
	local initial_reply = ""
	if mention_id ~= "" then
		initial_reply = "@{" .. mention_id .. "} "
	elseif mention_name ~= "" then
		initial_reply = "@" .. mention_name .. " "
	end
	markdown_editor.open({
		key = string.format("bitbucket-comment-reply-%s", tostring(comment.id or "")),
		title = "Reply to Comment",
		initial_text = initial_reply,
		width_ratio = 0.22,
		height_ratio = 0.22,
		completion = mention_completions.build_completion(),
		on_save = function(body)
			local final_body = tostring(body or "")
			if vim.trim(final_body) == "" then
				footer.notify("warn", "Reply cannot be empty")
				return
			end

			footer.notify("loading", "Adding reply...")
			comments_api.reply_comment(comments_url, comment.id, final_body, nil, function(created, err)
				if err ~= nil then
					footer.notify("error", tostring(err))
					return
				end

				if state.comments ~= "loading" then
					if type(state.comments) ~= "table" then
						state.comments = {}
					end
					if type(created) == "table" then
						table.insert(state.comments, created)
					end
				end

				footer.notify("success", "Reply added", 1200)
				require("atlas.bitbucket.panel.init").refresh()
			end)
		end,
	})
end

function M.toggle_task()
	local task = current_task_under_cursor()
	if task == nil then
		footer.notify("warn", "No task selected")
		return
	end
	toggle_task(task)
end

function M.edit_comment()
	local task = current_task_under_cursor()
	if task ~= nil then
		edit_task(task)
		return
	end

	local comment = current_comment_under_cursor()
	if comment == nil then
		footer.notify("warn", "No comment selected")
		return
	end

	if not helper.can_manage_comment(comment, bitbucket_state.current_user) then
		footer.notify("warn", "You can only edit your own comments")
		return
	end

	local comment_url = tostring((comment.links or {}).self or "")
	if comment_url == "" then
		footer.notify("error", "Missing comment URL")
		return
	end
	markdown_editor.open({
		key = string.format("bitbucket-comment-edit-%s", tostring(comment.id or "")),
		title = "Edit Comment",
		initial_text = tostring((comment.content or {}).raw or ""),
		width_ratio = 0.22,
		height_ratio = 0.22,
		completion = mention_completions.build_completion(),
		on_save = function(body)
			local final_body = tostring(body or "")
			if vim.trim(final_body) == "" then
				footer.notify("warn", "Comment cannot be empty")
				return
			end

			footer.notify("loading", "Updating comment...")
			comments_api.update_comment(comment_url, final_body, nil, function(updated, err)
				if err ~= nil then
					footer.notify("error", tostring(err))
					return
				end
				if state.comments == "loading" then
					return
				end

				if type(updated) == "table" then
					local next_comment = updated
					if type(state.comments) == "table" then
						local target_id = tonumber(next_comment.id)
						if target_id ~= nil then
							for i, entry in ipairs(state.comments) do
								if type(entry) == "table" and tonumber(entry.id) == target_id then
									state.comments[i] = next_comment
									break
								end
							end
						end
					end
				elseif type(comment.content) == "table" then
					comment.content.raw = final_body
				end

				footer.notify("success", "Comment updated", 1200)
				require("atlas.bitbucket.panel.init").refresh()
			end)
		end,
	})
end

function M.delete_comment()
	local task = current_task_under_cursor()
	if task ~= nil then
		delete_task(task)
		return
	end

	local comment = current_comment_under_cursor()
	if comment == nil then
		footer.notify("warn", "No comment selected")
		return
	end

	if not helper.can_manage_comment(comment, bitbucket_state.current_user) then
		footer.notify("warn", "You can only delete your own comments")
		return
	end

	local comment_url = tostring((comment.links or {}).self or "")
	if comment_url == "" then
		footer.notify("error", "Missing comment URL")
		return
	end

	vim.ui.input({
		prompt = string.format("Delete comment %s? [y/N]: ", tostring(comment.id or "")),
	}, function(input)
		if input == nil then
			return
		end

		local normalized = vim.trim(tostring(input)):lower()
		if normalized ~= "y" and normalized ~= "yes" then
			return
		end

		footer.notify("loading", "Deleting comment...")
		comments_api.delete_comment(comment_url, function(_, err)
			if err ~= nil then
				footer.notify("error", tostring(err))
				return
			end

			if state.comments == "loading" then
				return
			end

			if type(state.comments) == "table" then
				local target_id = tonumber(comment.id)
				if target_id ~= nil then
					for i = #state.comments, 1, -1 do
						local entry = state.comments[i]
						if type(entry) == "table" and tonumber(entry.id) == target_id then
							table.remove(state.comments, i)
						end
					end
				end
			end
			footer.notify("success", "Comment deleted", 1200)
			require("atlas.bitbucket.panel.init").refresh()
		end)
	end)
end

return M
