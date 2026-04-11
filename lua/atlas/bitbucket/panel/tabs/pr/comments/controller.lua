local M = {}
local state = require("atlas.bitbucket.panel.tabs.pr.comments.state")
local comments_api = require("atlas.bitbucket.api.comments")
local helper = require("atlas.bitbucket.panel.tabs.pr.comments.helper")
local mention_completions = require("atlas.bitbucket.completion.author")
local footer = require("atlas.ui.components.footer")
local bitbucket_state = require("atlas.bitbucket.state")
local markdown_editor = require("atlas.ui.popups.markdown_editor")

local active_handle = nil

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
	if item.kind ~= "header"
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

---@param lnum integer
---@return boolean
local function is_comment_line(lnum)
	local item = state.line_map[lnum]
	if item == nil or item.comment == nil then
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
		return
	end

	if same_pr and state.comments ~= nil and state.comments ~= "loading" then
		return
	end

	local comments_url = pr.links.comments
	if comments_url == "" then
		state.comments = nil
		footer.notify("error", "Missing comments URL")
		return
	end

	state.comments = "loading"
	footer.notify("loading", "Loading comments...")

	active_handle = comments_api.fetch_comments(comments_url, {}, function(comments, err)
		active_handle = nil

		if state.pr == nil or state.pr.id ~= next_id then
			return
		end

		if err ~= nil then
			state.comments = nil
			footer.notify("error", "Failed to load comments: " .. tostring(err))
		else
			state.comments = comments.entries
			footer.notify("success", "Comments loaded", 1200)
		end
	end)
end

---@param opts? { force_load?: boolean }
function M.refresh(opts)
	opts = opts or {}
	local pr = state.pr
	if pr == nil then
		return
	end

	local comments_url = pr.links.comments
	if comments_url == "" then
		return
	end

	cancel_active_handle()
	state.comments = "loading"

	active_handle = comments_api.fetch_comments(
		comments_url,
		{ force_load = opts.force_load == true },
		function(comments, err)
			active_handle = nil

			if state.pr == nil then
				return
			end

			if err ~= nil then
				state.comments = nil
				footer.notify("error", "Failed to refresh comments")
			else
				state.comments = comments.entries
				footer.notify("success", "Comments refreshed", 1200)
			end
		end
	)
end

function M.reset()
	cancel_active_handle()
	state.reset()
end

function M.deactivate() end

---@return boolean
function M.is_loading()
	return state.comments == "loading"
end

---@param lnum integer
---@return boolean
function M.is_selectable_line(lnum)
	return is_comment_line(lnum)
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
			comments_api.create_comment(comments_url, final_body, nil, function(_, err)
				if err ~= nil then
					footer.notify("error", tostring(err))
					return
				end

				footer.notify("success", "Comment added", 1200)
				M.refresh({ force_load = true })
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
	markdown_editor.open({
		key = string.format("bitbucket-comment-reply-%s", tostring(comment.id or "")),
		title = "Reply to Comment",
		initial_text = "",
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
			comments_api.reply_comment(comments_url, comment.id, final_body, nil, function(_, err)
				if err ~= nil then
					footer.notify("error", tostring(err))
					return
				end

				footer.notify("success", "Reply added", 1200)
				M.refresh({ force_load = true })
				require("atlas.bitbucket.panel.init").refresh()
			end)
		end,
	})
end

function M.edit_comment()
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
			comments_api.update_comment(comment_url, final_body, nil, function(_, err)
				if err ~= nil then
					footer.notify("error", tostring(err))
					return
				end

				footer.notify("success", "Comment updated", 1200)
				M.refresh({ force_load = true })
				require("atlas.bitbucket.panel.init").refresh()
			end)
		end,
	})
end

function M.delete_comment()
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

			footer.notify("success", "Comment deleted", 1200)
			M.refresh({ force_load = true })
			require("atlas.bitbucket.panel.init").refresh()
		end)
	end)
end

return M
