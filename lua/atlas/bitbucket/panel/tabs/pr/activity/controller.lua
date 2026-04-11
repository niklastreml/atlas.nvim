local M = {}
local state = require("atlas.bitbucket.panel.tabs.pr.activity.state")
local pr_state = require("atlas.bitbucket.panel.tabs.pr.state")
local pullrequests = require("atlas.bitbucket.api.pullrequests")
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
local function is_activity_line(lnum)
	local item = state.line_map[lnum]
	if item == nil then
		return false
	end
	return item.kind == "header"
		or item.kind == "content"
		or item.kind == "thread_header"
		or item.kind == "thread_content"
end

---@param win integer
---@param delta integer
---@return boolean
local function jump_next_activity(win, delta)
	local line = vim.api.nvim_win_get_cursor(win)[1]
	local buf = vim.api.nvim_win_get_buf(win)
	local max_line = vim.api.nvim_buf_line_count(buf)
	local step = delta > 0 and 1 or -1

	for lnum = line + step, (step > 0 and max_line or 1), step do
		if is_activity_line(lnum) then
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

	if same_pr and state.activity == "loading" then
		state.pr = pr
		state.line_map = {}
		require("atlas.bitbucket.panel.init").refresh()
		return
	end

	state.pr = pr
	state.line_map = {}

	if pr == nil then
		state.activity = nil
		return
	end

	if same_pr and state.activity ~= nil and state.activity ~= "loading" then
		return
	end

	local activity_url = pr.links.activity
	if activity_url == "" then
		state.activity = nil
		footer.notify("error", "Missing activity URL")
		return
	end

	state.activity = "loading"
	footer.notify("loading", "Loading activity...")
	require("atlas.bitbucket.panel.init").refresh()

	active_handle = pullrequests.fetch_activity(activity_url, function(activity, err)
		active_handle = nil

		if state.pr == nil or state.pr.id ~= next_id then
			return
		end

		if err ~= nil then
			state.activity = nil
			footer.notify("error", "Failed to load activity: " .. tostring(err))
		else
			state.activity = activity
			footer.notify("success", "Activity loaded", 1200)
		end

		require("atlas.bitbucket.panel.init").refresh()
	end)
end

function M.refresh()
	local pr = state.pr
	if pr == nil then
		return
	end

	local activity_url = pr.links.activity
	if activity_url == "" then
		return
	end

	cancel_active_handle()
	state.activity = "loading"
	require("atlas.bitbucket.panel.init").refresh()

	active_handle = pullrequests.fetch_activity(activity_url, function(activity, err)
		active_handle = nil

		if state.pr == nil then
			return
		end

		if err ~= nil then
			state.activity = nil
			footer.notify("error", "Failed to refresh activity")
		else
			state.activity = activity
			footer.notify("success", "Activity refreshed", 1200)
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
	return state.activity == "loading"
end

---@param delta integer
function M.move(delta)
	if pr_state.tab ~= "activity" then
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
			if is_activity_line(lnum) then
				vim.api.nvim_win_set_cursor(win, { lnum, 0 })
				return
			end
		end
		return
	end

	if delta == math.huge then
		for lnum = max_line, 1, -1 do
			if is_activity_line(lnum) then
				vim.api.nvim_win_set_cursor(win, { lnum, 0 })
				return
			end
		end
		return
	end

	if jump_next_activity(win, delta) then
		return
	end

	local line = vim.api.nvim_win_get_cursor(win)[1]
	local step = delta > 0 and 1 or -1
	local target = math.max(1, math.min(max_line, line + step))
	vim.api.nvim_win_set_cursor(win, { target, 0 })
end

return M
