local M = {}
local tab_state = require("atlas.bitbucket.panel.tabs.repo.branches.state")
local repo_state = require("atlas.bitbucket.panel.tabs.repo.state")
local repositories = require("atlas.bitbucket.api.repositories")
local footer = require("atlas.ui.components.footer")

local branches_handle = nil

local function cancel_handles()
	if branches_handle ~= nil and branches_handle.cancel then
		pcall(branches_handle.cancel)
	end
	branches_handle = nil
end

---@param repo BitbucketRepository|nil
---@param opts? { force_detail?: boolean, force_branches?: boolean }
function M.show(repo, opts)
	opts = opts or {}
	local prev_name = tab_state.repo and tab_state.repo.full_name or nil
	local next_name = repo and repo.full_name or nil
	local same_repo = prev_name == next_name

	if not same_repo then
		cancel_handles()
	end

	if same_repo and tab_state.branches == "loading" then
		tab_state.repo = repo
		tab_state.line_map = {}
		return
	end

	tab_state.repo = repo
	tab_state.line_map = {}

	if repo == nil then
		tab_state.branches = nil
		return
	end

	if same_repo and not opts.force_branches and tab_state.branches ~= nil and tab_state.branches ~= "loading" then
		return
	end

	local workspace = repo.workspace
	local repo_slug = repo.slug or repo.repo_slug
	if workspace == "" or repo_slug == "" then
		tab_state.branches = nil
		footer.notify("error", "Missing repository info")
		return
	end

	tab_state.branches = "loading"
	footer.notify("loading", "Loading branches...")

	local detail = repo_state.detail
	if detail == "loading" then
		return
	end
	if detail == nil then
		tab_state.branches = nil
		footer.notify("error", "Failed to load branches: missing repo detail")
		return
	end

	local branches_url = detail.links.branches
	if branches_url == "" then
		tab_state.branches = nil
		footer.notify("error", "Missing branches URL")
		return
	end

	branches_handle = repositories.fetch_branches(branches_url, {
		force_load = opts.force_branches == true,
	}, function(branches, fetch_err)
		branches_handle = nil

		if tab_state.repo == nil or tab_state.repo.full_name ~= next_name then
			return
		end

		if fetch_err ~= nil then
			tab_state.branches = nil
			footer.notify("error", "Failed to load branches: " .. tostring(fetch_err))
		else
			tab_state.branches = branches
			footer.notify("success", "Branches loaded", 1200)
		end
	end)
end

function M.refresh()
	if tab_state.repo == nil then
		return
	end

	cancel_handles()
	tab_state.branches = nil
	M.show(tab_state.repo, { force_detail = true, force_branches = true })
end

function M.reset()
	cancel_handles()
	tab_state.reset()
end

function M.deactivate()
end

---@return boolean
function M.is_loading()
	return tab_state.branches == "loading"
end

---@param delta integer
function M.move(delta)
	if repo_state.tab ~= "branches" then
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
