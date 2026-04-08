local M = {}
local state = require("atlas.bitbucket.panel.tabs.pr.files.state")
local panel_state = require("atlas.bitbucket.panel.state")
local pullrequests = require("atlas.bitbucket.api.pullrequests")
local diff_parser = require("atlas.core.git.diff_parser")
local spinner = require("atlas.ui.components.spinner")
local footer = require("atlas.ui.components.footer")
local checkout = require("atlas.core.git.checkout")

local diff_handle = nil

local panel_spinner
panel_spinner = spinner.create({
	interval_ms = 120,
	on_tick = function()
		if state.diff ~= "loading" then
			panel_spinner:stop()
			return
		end

		if panel_state.current_tab ~= "files" then
			return
		end

		require("atlas.bitbucket.panel.init").refresh()
	end,
})

local function cancel_handles()
	if diff_handle ~= nil and diff_handle.cancel then
		pcall(diff_handle.cancel)
	end
	diff_handle = nil
end

local function stop_spinner()
	panel_spinner:stop()
end

local function start_spinner()
	if panel_spinner:is_running() then
		return
	end
	panel_spinner:start()
end

---@param pr BitbucketPR|nil
function M.show(pr)
	local prev_id = state.pr and state.pr.id or nil
	local next_id = pr and pr.id or nil
	local same_pr = prev_id == next_id

	if not same_pr then
		cancel_handles()
		state.collapsed_hunks = {}
		state.hunk_headers = {}
	end

	if same_pr and state.diff == "loading" then
		state.pr = pr
		state.line_map = {}
		start_spinner()
		require("atlas.bitbucket.panel.init").refresh()
		return
	end

	stop_spinner()
	state.pr = pr
	state.line_map = {}

	if pr == nil then
		state.diff = nil
		return
	end

	if same_pr and state.diff ~= nil and state.diff ~= "loading" then
		return
	end

	local diff_url = (pr.links or {}).diff

	if type(diff_url) ~= "string" or diff_url == "" then
		state.diff = nil
		footer.notify("error", "Missing diff URL")
	else
		state.diff = "loading"
		start_spinner()

		diff_handle = pullrequests.fetch_diff(diff_url, function(diff, err)
			diff_handle = nil

			if state.pr == nil or state.pr.id ~= next_id then
				return
			end

			if err ~= nil then
				state.diff = nil
				footer.notify("error", "Failed to load diff: " .. tostring(err))
			else
				state.diff = diff_parser.parse(diff)
				stop_spinner()
				footer.notify("success", "Files loaded", 1200)
			end
			require("atlas.bitbucket.panel.init").refresh()
		end)
	end

	footer.notify("loading", "Loading file changes...")
	require("atlas.bitbucket.panel.init").refresh()
end

function M.refresh()
	if state.pr == nil then
		return
	end

	local pr = state.pr
	local diff_url = (pr.links or {}).diff

	cancel_handles()
	state.diff = "loading"
	start_spinner()
	require("atlas.bitbucket.panel.init").refresh()

	if type(diff_url) == "string" and diff_url ~= "" then
		diff_handle = pullrequests.fetch_diff(diff_url, function(diff, err)
			diff_handle = nil

			if state.pr == nil then
				return
			end

			if err ~= nil then
				state.diff = nil
			else
				state.diff = diff_parser.parse(diff)
			end

			stop_spinner()
			footer.notify("success", "Files refreshed", 1200)
			require("atlas.bitbucket.panel.init").refresh()
		end)
	end
end

function M.reset()
	cancel_handles()
	stop_spinner()
	state.reset()
end

--- Toggle fold on the hunk header under the cursor.
function M.toggle_fold()
	if panel_state.current_tab ~= "files" then
		return
	end

	local layout = require("atlas.ui.layout")
	local win = layout.win_id("detail")
	if win == nil or not vim.api.nvim_win_is_valid(win) then
		return
	end

	local lnum = vim.api.nvim_win_get_cursor(win)[1]
	local entry = (state.line_map or {})[lnum]
	if type(entry) ~= "table" or entry.type ~= "hunk_header" then
		return
	end

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
	if panel_state.current_tab ~= "files" then
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
		return type(e) == "table" and e.type == "hunk_header"
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

	if not pcall(require, "diffview") then
		footer.notify("warn", "diffview.nvim is not installed")
		return
	end

	local repo_path, err = checkout.resolve_repo_path_for_pr(pr, { require_git = true, require_existing = true })
	if repo_path == nil then
		footer.notify("warn", "Local repo not found: " .. tostring(err))
		return
	end

	local src = tostring((pr.source or {}).branch or "")
	local dst = tostring((pr.destination or {}).branch or "")
	if src == "" or dst == "" then
		footer.notify("warn", "PR branch refs are missing")
		return
	end

	footer.notify("loading", "Fetching remote branches...")

	checkout.fetch_pr_branches(pr, repo_path, function(fetch_err)
		if fetch_err ~= nil then
			footer.notify("error", "Fetch failed: " .. fetch_err)
			return
		end

		-- Three-dot range: what changed in src relative to the merge base with dst.
		local range = "origin/" .. dst .. "...origin/" .. src
		local prev_cwd = vim.fn.chdir(repo_path)
		local open_ok, open_err = pcall(function()
			vim.cmd("DiffviewOpen " .. range)
		end)
		vim.fn.chdir(prev_cwd)

		if not open_ok then
			footer.notify("error", "DiffviewOpen failed: " .. tostring(open_err))
		end
	end)
end

function M.deactivate()
	stop_spinner()
end

---@param delta integer
function M.move(delta)
	if panel_state.current_tab ~= "files" then
		return
	end

	local layout = require("atlas.ui.layout")
	local win = layout.win_id("detail")
	if win == nil or not vim.api.nvim_win_is_valid(win) then
		return
	end

	local buf = vim.api.nvim_win_get_buf(win)
	local max_line = vim.api.nvim_buf_line_count(buf)

	if delta == 0 then
		vim.api.nvim_win_set_cursor(win, { 1, 0 })
		return
	end

	if delta == math.huge then
		vim.api.nvim_win_set_cursor(win, { max_line, 0 })
		return
	end

	local line = vim.api.nvim_win_get_cursor(win)[1]
	local step = delta > 0 and 1 or -1
	local target = math.max(1, math.min(max_line, line + step))
	vim.api.nvim_win_set_cursor(win, { target, 0 })
end

return M
