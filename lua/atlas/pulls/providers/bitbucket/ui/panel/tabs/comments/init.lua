---@class BitbucketPullsCommentsTab : PullsPanelTabModule
local M = {}

local bb_helper = require("atlas.pulls.providers.bitbucket.ui.panel.tabs.comments.helper")
local renderer = require("atlas.pulls.providers.bitbucket.ui.panel.tabs.comments.renderer")
local md_editor = require("atlas.ui.popups.markdown_editor")
local footer = require("atlas.ui.components.footer")
local state = require("atlas.pulls.providers.bitbucket.ui.panel.tabs.comments.state")
local comments_api = require("atlas.pulls.providers.bitbucket.api.comments")
local author_completion = require("atlas.pulls.providers.bitbucket.completion.author")
local panel_state = require("atlas.pulls.ui.panel.pr.state")

---@type { cancel: fun() }[]
local in_flight = {}

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------

local function cancel_all()
	for _, handle in ipairs(in_flight) do
		handle.cancel()
	end
	in_flight = {}
end

---@param handle { cancel: fun() }|nil
local function track(handle)
	if handle then
		table.insert(in_flight, handle)
	end
end

---@param comment PullsComment
---@return boolean
local function is_own_comment(comment)
	local current_user = require("atlas.pulls.state").current_user
	if not current_user or not comment.author then
		return false
	end
	return comment.author.nickname == current_user.username or comment.author.name == current_user.name
end

-- -----------------------------------------------------------------------------
-- Comments
-- -----------------------------------------------------------------------------

---@param pr PullRequest
---@param _repo PullsRepo|nil
---@param done fun()
---@param opts { force_refresh: boolean|nil }|nil
function M.on_select(pr, _repo, done, opts)
	cancel_all()
	state.reset()

	local workspace = tostring(pr.workspace or "")
	local repo_slug = tostring(pr.repo or "")
	if workspace == "" or repo_slug == "" then
		return
	end

	local pending = 2
	local function finish_one()
		pending = pending - 1
		if pending == 0 then
			done()
		end
	end

	state.comments = "loading"
	state.tasks = "loading"
	local pr_id = tostring(pr.id or "")
	footer.notify("loading", string.format("Loading comments for #%s...", pr_id))

	track(comments_api.fetch_comments(pr, opts, function(comments, err)
		if err then
			state.comments = err
			footer.notify("error", string.format("Failed to load comments for #%s", pr_id))
		else
			state.comments = comments or {}
			footer.notify("success", string.format("Comments loaded for #%s", pr_id), 1200)
		end
		finish_one()
	end))

	track(comments_api.fetch_tasks(workspace, repo_slug, pr.id, {
		force_refresh = opts and opts.force_refresh == true,
	}, function(tasks, err)
		if err then
			state.tasks = nil
			footer.notify("error", "Failed to load tasks")
		else
			state.tasks = tasks and tasks.entries or {}
		end
		finish_one()
	end))
end

---@param pr PullRequest
---@param width integer
---@return string[], table[], table<integer, table>|nil
function M.render(pr, width)
	return renderer.render(pr, width, state.comments, state.tasks)
end

---@param _lnum integer
---@param entry table
---@return boolean
function M.is_selectable_line(_lnum, entry)
	local k = entry.kind
	return k == "header" or k == "content" or k == "thread_header" or k == "thread_content"
end

---@param pr PullRequest
---@param entry table
function M.on_enter(pr, entry)
	local task = entry.task
	local comment = entry.comment
	if task ~= nil and entry.entity_kind == "task" then
		local url = tostring((task.links or {}).html or "")
		if url ~= "" then
			vim.ui.open(url)
		end
		return
	end
	if comment ~= nil and entry.entity_kind == "comment" then
		local url = tostring(comment.html_url or "")
		if url ~= "" then
			vim.ui.open(url)
		end
	end
end

local keymaps = require("atlas.pulls.providers.bitbucket.ui.panel.tabs.comments.keymaps")
M.setup_keymaps = keymaps.setup
M.teardown_keymaps = keymaps.teardown

---@param pr PullRequest
---@return PullsAuthor[]
local function collect_completion_authors(pr)
	---@type table<string, PullsAuthor>
	local seen = {}

	---@param author { name: string, nickname: string|nil, id: string|nil }|PullsAuthor|nil
	local function add(author)
		if type(author) ~= "table" then
			return
		end
		local id = tostring(author.id or "")
		if id == "" or seen[id] ~= nil then
			return
		end
		seen[id] = {
			id = id,
			name = tostring(author.name or ""),
			username = tostring(author.nickname or author.username or ""),
		}
	end

	add(pr.author)

	if type(state.comments) == "table" then
		for _, comment in ipairs(state.comments) do
			add(comment and comment.author or nil)
		end
	end

	if type(state.tasks) == "table" then
		for _, task in ipairs(state.tasks) do
			add(task and task.creator or nil)
		end
	end

	return vim.tbl_values(seen)
end

---@param pr PullRequest
---@return AtlasMarkdownCompletionProvider|nil
local function get_completion(pr)
	local authors = collect_completion_authors(pr)
	if #authors == 0 then
		return nil
	end
	return author_completion.build_completion(authors)
end

---@param pr PullRequest
---@param opts { key: string, title: string, initial_text: string|nil, width_ratio: number|nil, height_ratio: number|nil, completion: AtlasMarkdownCompletionProvider|nil, on_save: fun(text: string|nil) }
local function open_md_editor(pr, opts)
	md_editor.open({
		key = opts.key,
		title = opts.title,
		width_ratio = opts.width_ratio or 0.5,
		height_ratio = opts.height_ratio or 0.18,
		initial_text = opts.initial_text,
		completion = opts.completion or get_completion(pr),
		on_save = opts.on_save,
	})
end

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

-- -----------------------------------------------------------------------------
-- Comments (Actions)
-- -----------------------------------------------------------------------------

---@param pr PullRequest
---@param done fun()
function M.add_comment(pr, done)
	open_md_editor(pr, {
		key = "pr-comment-add",
		title = " Add Comment ",
		on_save = function(text)
			if not text or vim.trim(text) == "" then
				return
			end
			footer.notify("loading", "Adding comment...")
			track(comments_api.add_comment(pr, text, function(comment, err)
				if err then
					footer.notify("error", "Add comment failed: " .. err)
					return
				end
				if type(comment) == "table" and type(state.comments) == "table" then
					table.insert(state.comments, comment)
				end
				footer.notify("success", "Comment added", 1200)
				done()
			end))
		end,
	})
end

---@param pr PullRequest
---@param entry table
---@param done fun()
function M.reply_comment(pr, entry, done)
	local comment = entry.comment
	if not comment then
		return
	end

	local author = comment.author or {}
	local mention_id = tostring(author.id or "")
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

	open_md_editor(pr, {
		key = "pr-comment-reply-" .. tostring(comment.id),
		title = " Reply to Comment ",
		initial_text = initial_reply,
		on_save = function(text)
			if not text or vim.trim(text) == "" then
				return
			end
			footer.notify("loading", "Sending reply...")
			track(comments_api.reply_comment(pr, comment.id, text, function(reply, err)
				if err then
					footer.notify("error", "Reply failed: " .. err)
					return
				end
				if type(reply) == "table" and type(state.comments) == "table" then
					table.insert(state.comments, reply)
				end
				footer.notify("success", "Reply added", 1200)
				done()
			end))
		end,
	})
end

-- -----------------------------------------------------------------------------
-- Tasks
-- -----------------------------------------------------------------------------

---@param pr PullRequest
---@param task BitbucketPRTask
---@param done fun()
---@param current_user PullsUser|nil
---@return boolean
local function edit_task(pr, task, done, current_user)
	if not bb_helper.can_manage_task(task, current_user) then
		footer.notify("warn", "You can only edit your own tasks")
		return false
	end
	local task_url = tostring((task.links or {}).self or "")
	if task_url == "" then
		footer.notify("error", "Missing task URL")
		return false
	end

	open_md_editor(pr, {
		key = string.format("bitbucket-task-edit-%s", tostring(task.id or "")),
		title = " Edit Task ",
		initial_text = tostring(task.content_raw or ""),
		on_save = function(text)
			if not text or vim.trim(text) == "" then
				footer.notify("warn", "Task cannot be empty")
				return
			end
			footer.notify("loading", "Updating task...")
			track(comments_api.update_task(task_url, {
				state = tostring(task.state or "UNRESOLVED"),
				content_raw = text,
			}, function(updated, err)
				if err then
					footer.notify("error", tostring(err))
					return
				end
				if type(updated) == "table" then
					upsert_local_task(updated)
				end
				footer.notify("success", "Task updated", 1200)
				done()
			end))
		end,
	})

	return true
end

---@param task BitbucketPRTask
---@param done fun()
---@param current_user PullsUser|nil
---@return boolean
local function delete_task(task, done, current_user)
	if not bb_helper.can_manage_task(task, current_user) then
		footer.notify("warn", "You can only delete your own tasks")
		return false
	end
	local task_url = tostring((task.links or {}).self or "")
	if task_url == "" then
		footer.notify("error", "Missing task URL")
		return false
	end

	vim.ui.input({
		prompt = string.format("Delete task %s? [y/N]: ", tostring(task.id or "")),
	}, function(input)
		local confirmed = input and vim.trim(input):lower()
		if confirmed ~= "y" and confirmed ~= "yes" then
			return
		end
		footer.notify("loading", "Deleting task...")
		track(comments_api.delete_task(task_url, function(_, err)
			if err then
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
						local te = state.tasks[i]
						if type(te) == "table" and tonumber(te.id) == target_id then
							table.remove(state.tasks, i)
						end
					end
				end
			end
			footer.notify("success", "Task deleted", 1200)
			done()
		end))
	end)

	return true
end

---@param pr PullRequest
---@param entry table
---@param done fun()
function M.edit_comment(pr, entry, done)
	local current_user = require("atlas.pulls.state").current_user

	local task = entry.task
	if task ~= nil and entry.entity_kind == "task" then
		edit_task(pr, task, done, current_user)
		return
	end

	local comment = entry.comment
	if not comment or not is_own_comment(comment) then
		return
	end

	open_md_editor(pr, {
		key = "pr-comment-edit-" .. tostring(comment.id),
		title = " Edit Comment ",
		initial_text = comment.content_raw or "",
		on_save = function(text)
			if not text or vim.trim(text) == "" then
				return
			end
			footer.notify("loading", "Editing comment...")
			track(comments_api.edit_comment(pr, comment.id, text, function(updated, err)
				if err then
					footer.notify("error", "Edit failed: " .. err)
					return
				end
				if type(state.comments) == "table" then
					for i, c in ipairs(state.comments) do
						if c.id == comment.id then
							state.comments[i].content_raw = text
							break
						end
					end
				end
				footer.notify("success", "Comment updated", 1200)
				done()
			end))
		end,
	})
end

---@param pr PullRequest
---@param entry table
---@param done fun()
function M.delete_comment(pr, entry, done)
	local current_user = require("atlas.pulls.state").current_user

	local task = entry.task
	if task ~= nil and entry.entity_kind == "task" then
		delete_task(task, done, current_user)
		return
	end

	local comment = entry.comment
	if not comment or not is_own_comment(comment) then
		return
	end

	vim.ui.input({ prompt = "Delete comment? [y/N]: " }, function(input)
		local confirmed = input and vim.trim(input):lower()
		if confirmed ~= "y" and confirmed ~= "yes" then
			return
		end
		footer.notify("loading", "Deleting comment...")
		track(comments_api.delete_comment(pr, comment.id, function(ok, err)
			if err then
				footer.notify("error", "Delete failed: " .. err)
				return
			end
			if ok and type(state.comments) == "table" then
				for i, c in ipairs(state.comments) do
					if c.id == comment.id then
						table.remove(state.comments, i)
						break
					end
				end
			end
			footer.notify("success", "Comment deleted", 1200)
			done()
		end))
	end)
end

---@param _pr PullRequest
---@param entry table
---@param done fun()
function M.toggle_task(_pr, entry, done)
	local task = entry.task
	if task == nil or entry.entity_kind ~= "task" then
		footer.notify("warn", "No task selected")
		return
	end
	local task_url = tostring((task.links or {}).self or "")
	if task_url == "" then
		footer.notify("error", "Missing task URL")
		return
	end

	local is_resolved = tostring(task.state or "") == "RESOLVED"
	local next_state = is_resolved and "UNRESOLVED" or "RESOLVED"
	footer.notify("loading", is_resolved and "Reopening task..." or "Resolving task...")
	track(comments_api.update_task(task_url, {
		state = next_state,
		content_raw = tostring(task.content_raw or ""),
	}, function(updated, err)
		if err then
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
		done()
	end))
end

---@param pr PullRequest
---@param done fun()
function M.add_task(pr, done)
	local workspace = tostring(pr.workspace or "")
	local repo_slug = tostring(pr.repo or "")
	local pr_id = tostring(pr.id or "")
	if workspace == "" or repo_slug == "" or pr_id == "" then
		footer.notify("error", "Missing PR info")
		return
	end

	local win = require("atlas.ui.layout").win_id("detail")
	local comment_id = nil
	if win and vim.api.nvim_win_is_valid(win) then
		local lnum = vim.api.nvim_win_get_cursor(win)[1]
		local ent = (panel_state.line_map or {})[lnum]
		if ent and ent.entity_kind == "comment" and ent.comment then
			comment_id = ent.comment.id
		end
	end

	open_md_editor(pr, {
		key = string.format("bitbucket-task-add-%s", pr_id),
		title = " Add Task ",
		on_save = function(text)
			if not text or vim.trim(text) == "" then
				footer.notify("warn", "Task cannot be empty")
				return
			end
			footer.notify("loading", "Adding task...")
			track(comments_api.create_task(workspace, repo_slug, pr.id, text, {
				comment_id = comment_id,
			}, function(created, err)
				if err then
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
				done()
			end))
		end,
	})
end

return M
