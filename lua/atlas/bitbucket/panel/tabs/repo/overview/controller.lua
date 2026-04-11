local M = {}
local tab_state = require("atlas.bitbucket.panel.tabs.repo.overview.state")
local repo_state = require("atlas.bitbucket.panel.tabs.repo.state")
local repositories = require("atlas.bitbucket.api.repositories")
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

	local detail_loading = repo_state.detail == "loading"
	local readme_loading = tab_state.readme == "loading"
	if same_repo and (detail_loading or readme_loading) then
		tab_state.repo = repo
		tab_state.line_map = {}
		return
	end

	tab_state.repo = repo
	tab_state.line_map = {}

	if repo == nil then
		repo_state.detail = nil
		return
	end

	if
		same_repo
		and not opts.force_detail
		and not opts.force_readme
		and repo_state.detail ~= nil
		and repo_state.detail ~= "loading"
		and tab_state.readme ~= nil
		and tab_state.readme ~= "loading"
	then
		return
	end

	local workspace = repo.workspace
	local repo_slug = repo.slug
	if workspace == "" or repo_slug == "" then
		repo_state.detail = nil
		tab_state.readme = nil
		footer.notify("error", "Missing repository info")
		return
	end

	tab_state.readme = "loading"
	footer.notify("loading", "Loading repository...")

	local detail = repo_state.detail
	if detail == "loading" then
		return
	end
	if detail == nil then
		tab_state.readme = nil
		footer.notify("error", "Failed to load repo detail")
		return
	end

	local ref = detail.mainbranch or "-"
	local readme_path = repo.readme
	readme_handle = repositories.fetch_readme(
		workspace,
		repo_slug,
		ref,
		readme_path,
		{ force_load = opts.force_readme == true },
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
		end
	)
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
	tab_state.reset()
end

function M.deactivate() end

---@return boolean
function M.is_loading()
	return repo_state.detail == "loading" or tab_state.readme == "loading"
end

---@param _lnum integer
---@return boolean
function M.is_selectable_line(_lnum)
	return true
end

return M
