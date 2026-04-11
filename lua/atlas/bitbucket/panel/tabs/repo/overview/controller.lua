local M = {}
local tab_state = require("atlas.bitbucket.panel.tabs.repo.overview.state")
local state = require("atlas.bitbucket.panel.tabs.repo.state")
local panel_state = require("atlas.bitbucket.panel.state")
local repositories = require("atlas.bitbucket.api.repositories")
local detail_loader = require("atlas.bitbucket.panel.tabs.repo.detail_loader")
local footer = require("atlas.ui.components.footer")

local readme_handle = nil

local function cancel_handles()
	if readme_handle ~= nil and readme_handle.cancel then
		pcall(readme_handle.cancel)
	end
	readme_handle = nil
end

---@param repo BitbucketRepository|nil
---@param opts? { force_detail?: boolean, force_readme?: boolean }
function M.show(repo, opts)
	opts = opts or {}
	local prev_name = tab_state.repo and tab_state.repo.full_name or nil
	local next_name = repo and repo.full_name or nil
	local same_repo = prev_name == next_name

	if not same_repo then
		cancel_handles()
	end

	local detail_loading = state.detail == "loading"
	local readme_loading = tab_state.readme == "loading"
	if same_repo and (detail_loading or readme_loading) then
		tab_state.repo = repo
		tab_state.line_map = {}
		require("atlas.bitbucket.panel.init").refresh()
		return
	end

	tab_state.repo = repo
	tab_state.line_map = {}

	if repo == nil then
		state.reset()
		return
	end

	if
		same_repo
		and not opts.force_detail
		and not opts.force_readme
		and state.detail ~= nil
		and state.detail ~= "loading"
		and tab_state.readme ~= nil
		and tab_state.readme ~= "loading"
	then
		return
	end

	local workspace = repo.workspace
	local repo_slug = repo.slug or repo.repo_slug

	if workspace == "" or repo_slug == "" then
		detail_loader.reset()
		tab_state.readme = nil
		footer.notify("error", "Missing repository info")
		return
	end

	tab_state.readme = "loading"
	detail_loader.ensure(repo, { force = opts.force_detail == true }, function(detail, err)

		if tab_state.repo == nil or tab_state.repo.full_name ~= next_name then
			return
		end

		if err ~= nil or not detail then
			tab_state.readme = nil
			footer.notify("error", "Failed to load repo detail: " .. tostring(err))
		else
			local ref = detail.mainbranch or "-"
			local readme_path = repo.readme

			tab_state.readme = "loading"
			readme_handle = repositories.fetch_readme(
				workspace,
				repo_slug,
				ref,
				readme_path,
				{},
				function(readme, readme_err)
					readme_handle = nil

					if tab_state.repo == nil or tab_state.repo.full_name ~= next_name then
						return
					end

					if readme_err ~= nil then
						tab_state.readme = nil
					else
						tab_state.readme = readme
					end

					footer.notify("success", "Repository loaded", 1200)
					require("atlas.bitbucket.panel.init").refresh()
				end
			)
		end

		require("atlas.bitbucket.panel.init").refresh()
	end)

	footer.notify("loading", "Loading repository...")
	require("atlas.bitbucket.panel.init").refresh()
end

function M.refresh()
	if tab_state.repo == nil then
		return
	end

	cancel_handles()
	tab_state.readme = nil
	M.show(tab_state.repo, { force_detail = true, force_readme = true })
end

function M.reset()
	cancel_handles()
	detail_loader.reset()
	tab_state.reset()
end

function M.deactivate()
end

---@return boolean
function M.is_loading()
	return state.detail == "loading" or tab_state.readme == "loading"
end

---@param delta integer
function M.move(delta)
	if panel_state.current_tab ~= "overview" then
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
