local M = {}
local tab_state = require("atlas.bitbucket.panel.tabs.repo.tags.state")
local repo_state = require("atlas.bitbucket.panel.tabs.repo.state")
local repositories = require("atlas.bitbucket.api.repositories")
local footer = require("atlas.ui.components.footer")

local tags_handle = nil

local function cancel_handles()
	if tags_handle ~= nil and tags_handle.cancel then
		pcall(tags_handle.cancel)
	end
	tags_handle = nil
end

---@param repo BitbucketRepository|nil
---@param opts? { force_detail?: boolean, force_tags?: boolean }
function M.show(repo, opts)
	opts = opts or {}
	local prev_name = tab_state.repo and tab_state.repo.full_name or nil
	local next_name = repo and repo.full_name or nil
	local same_repo = prev_name == next_name

	if not same_repo then
		cancel_handles()
	end

	if same_repo and tab_state.tags == "loading" then
		tab_state.repo = repo
		tab_state.line_map = {}
		return
	end

	tab_state.repo = repo
	tab_state.line_map = {}

	if repo == nil then
		tab_state.tags = nil
		return
	end

	if same_repo and not opts.force_tags and tab_state.tags ~= nil and tab_state.tags ~= "loading" then
		return
	end

	tab_state.tags = "loading"
	footer.notify("loading", "Loading tags...")

	local detail = repo_state.detail
	if detail == "loading" then
		return
	end
	if detail == nil then
		tab_state.tags = nil
		footer.notify("error", "Failed to load tags: missing repo detail")
		return
	end

	local tags_url = detail.links.tags
	if tags_url == "" then
		tab_state.tags = nil
		footer.notify("error", "Missing tags URL")
		return
	end

	tags_handle = repositories.fetch_tags(tags_url, {
		force_load = opts.force_tags == true,
	}, function(tags, fetch_err)
		tags_handle = nil

		if tab_state.repo == nil or tab_state.repo.full_name ~= next_name then
			return
		end

		if fetch_err ~= nil then
			tab_state.tags = nil
			footer.notify("error", "Failed to load tags: " .. tostring(fetch_err))
		else
			tab_state.tags = tags
			footer.notify("success", "Tags loaded", 1200)
		end
	end)
end

function M.refresh()
	if tab_state.repo == nil then
		return
	end

	cancel_handles()
	tab_state.tags = nil
	M.show(tab_state.repo, { force_detail = true, force_tags = true })
end

function M.reset()
	cancel_handles()
	tab_state.reset()
end

function M.deactivate()
end

---@return boolean
function M.is_loading()
	return repo_state.detail == "loading" or tab_state.tags == "loading"
end

---@param delta integer
function M.move(delta)
	if repo_state.tab ~= "tags" then
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
