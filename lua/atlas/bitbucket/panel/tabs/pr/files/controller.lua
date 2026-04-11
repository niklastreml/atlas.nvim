local M = {}
local state = require("atlas.bitbucket.panel.tabs.pr.files.state")
local pr_state = require("atlas.bitbucket.panel.tabs.pr.state")
local pullrequests = require("atlas.bitbucket.api.pullrequests")
local actions = require("atlas.bitbucket.actions")
local diff_parser = require("atlas.core.git.diff_parser")
local footer = require("atlas.ui.components.footer")

local diff_handle = nil

local function cancel_handles()
	if diff_handle ~= nil and diff_handle.cancel then
		pcall(diff_handle.cancel)
	end
	diff_handle = nil
end

---@param pr BitbucketPR|nil
function M.show(pr)
	local prev_id = state.pr and state.pr.id or nil
	local next_id = pr and pr.id or nil
	local same_pr = prev_id == next_id

	if not same_pr then
		cancel_handles()
		state.collapsed_hunks = {}
	end

	if same_pr and state.diff == "loading" then
		state.pr = pr
		state.line_map = {}
		return
	end

	state.pr = pr
	state.line_map = {}

	if pr == nil then
		state.diff = nil
		return
	end

	if same_pr and state.diff ~= nil and state.diff ~= "loading" then
		return
	end

	local diff_url = pr.links.diff

	if diff_url == "" then
		state.diff = nil
		footer.notify("error", "Missing diff URL")
	else
		state.diff = "loading"

		diff_handle = pullrequests.fetch_diff(diff_url, {}, function(diff, err)
			diff_handle = nil

			if state.pr == nil or state.pr.id ~= next_id then
				return
			end

			if err ~= nil then
				state.diff = nil
				footer.notify("error", "Failed to load diff: " .. tostring(err))
			else
				state.diff = diff_parser.parse(diff)
				footer.notify("success", "Files loaded", 1200)
			end
		end)
	end

	footer.notify("loading", "Loading file changes...")
end

---@param opts? { force_load?: boolean }
function M.refresh(opts)
	opts = opts or {}
	if state.pr == nil then
		return
	end

	local pr = state.pr
	local diff_url = pr.links.diff

	cancel_handles()
	state.diff = "loading"

	if diff_url ~= "" then
		diff_handle = pullrequests.fetch_diff(diff_url, { force_load = opts.force_load == true }, function(diff, err)
			diff_handle = nil

			if state.pr == nil then
				return
			end

			if err ~= nil then
				state.diff = nil
			else
				state.diff = diff_parser.parse(diff)
			end

			footer.notify("success", "Files refreshed", 1200)
		end)
	end
end

function M.reset()
	cancel_handles()
	state.reset()
end

--- Toggle fold on the hunk header under the cursor.
function M.toggle_fold()
	if pr_state.tab ~= "files" then
		return
	end

	local layout = require("atlas.ui.layout")
	local win = layout.win_id("detail")
	if win == nil or not vim.api.nvim_win_is_valid(win) then
		return
	end

	local line_map = state.line_map or {}
	local lnum = vim.api.nvim_win_get_cursor(win)[1]
	local entry = line_map[lnum]
	local header_lnum = lnum

	-- If not on a header, walk up to find the enclosing hunk header
	if entry == nil or entry.type ~= "hunk_header" then
		for l = lnum - 1, 1, -1 do
			local e = line_map[l]
			if e ~= nil and e.type == "hunk_header" then
				entry = e
				header_lnum = l
				break
			end
		end
	end

	if entry == nil or entry.type ~= "hunk_header" then
		return
	end

	vim.api.nvim_win_set_cursor(win, { header_lnum, 0 })
	local hunk_idx = entry.hunk_idx
	if state.collapsed_hunks[hunk_idx] then
		state.collapsed_hunks[hunk_idx] = nil
	else
		state.collapsed_hunks[hunk_idx] = true
	end

	require("atlas.bitbucket.panel.init").refresh()
end

--- Jump to the next (delta=1) or previous (delta=-1) hunk header.
---@param delta integer
function M.jump_hunk(delta)
	if pr_state.tab ~= "files" then
		return
	end

	local layout = require("atlas.ui.layout")
	local win = layout.win_id("detail")
	if win == nil or not vim.api.nvim_win_is_valid(win) then
		return
	end

	local buf = vim.api.nvim_win_get_buf(win)
	local max_line = vim.api.nvim_buf_line_count(buf)
	local current_line = vim.api.nvim_win_get_cursor(win)[1]
	local line_map = state.line_map or {}

	local function is_hunk_header(lnum)
		local e = line_map[lnum]
		return e ~= nil and e.type == "hunk_header"
	end

	local target = nil

	if delta > 0 then
		for lnum = current_line + 1, max_line do
			if is_hunk_header(lnum) then
				target = lnum
				break
			end
		end
		if target == nil then
			for lnum = 1, current_line do
				if is_hunk_header(lnum) then
					target = lnum
					break
				end
			end
		end
	else
		for lnum = current_line - 1, 1, -1 do
			if is_hunk_header(lnum) then
				target = lnum
				break
			end
		end
		if target == nil then
			for lnum = max_line, current_line, -1 do
				if is_hunk_header(lnum) then
					target = lnum
					break
				end
			end
		end
	end

	if target then
		vim.api.nvim_win_set_cursor(win, { target, 0 })
	end
end

function M.open_diffview()
	local pr = state.pr
	if pr == nil then
		footer.notify("warn", "No PR selected")
		return
	end

	actions.run("open_diffview", {
		pr = pr,
		source = "panel",
	}, function() end)
end

function M.deactivate()
end

---@return boolean
function M.is_loading()
	return state.diff == "loading"
end

---@param _lnum integer
---@return boolean
function M.is_selectable_line(_lnum)
	return true
end

return M
