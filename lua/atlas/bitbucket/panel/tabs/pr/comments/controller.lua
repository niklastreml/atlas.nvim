local M = {}
local state = require("atlas.bitbucket.panel.tabs.pr.comments.state")
local panel_state = require("atlas.bitbucket.panel.state")
local pullrequests = require("atlas.bitbucket.api.pullrequests")
local helper = require("atlas.bitbucket.panel.tabs.pr.comments.helper")
local footer = require("atlas.ui.components.footer")

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

---@param lnum integer
---@return boolean
local function is_comment_line(lnum)
	local item = state.line_map[lnum]
	if item == nil or item.comment == nil then
		return false
	end
	return item.kind == "content" or item.kind == "thread_content"
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
		require("atlas.bitbucket.panel.init").refresh()
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
	require("atlas.bitbucket.panel.init").refresh()

	active_handle = pullrequests.fetch_comments(comments_url, {}, function(comments, err)
		active_handle = nil

		if state.pr == nil or state.pr.id ~= next_id then
			return
		end

		if err ~= nil then
			state.comments = nil
			footer.notify("error", "Failed to load comments: " .. tostring(err))
		else
			state.comments = helper.normalize_comments(comments.entries)
			footer.notify("success", "Comments loaded", 1200)
		end

		require("atlas.bitbucket.panel.init").refresh()
	end)
end

function M.refresh()
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
	require("atlas.bitbucket.panel.init").refresh()

	active_handle = pullrequests.fetch_comments(comments_url, { force_load = true }, function(comments, err)
		active_handle = nil

		if state.pr == nil then
			return
		end

		if err ~= nil then
			state.comments = nil
			footer.notify("error", "Failed to refresh comments")
		else
			state.comments = helper.normalize_comments(comments.entries)
			footer.notify("success", "Comments refreshed", 1200)
		end

		require("atlas.bitbucket.panel.init").refresh()
	end)
end

function M.reset()
	cancel_active_handle()
	state.reset()
end

function M.deactivate()
end

---@return boolean
function M.is_loading()
	return state.comments == "loading"
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

return M
