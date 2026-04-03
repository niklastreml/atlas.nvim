local M = {}
local state = require("atlas.bitbucketv2.panel.tabs.repo.overview.state")
local panel_state = require("atlas.bitbucketv2.panel.state")
local repositories = require("atlas.bitbucketv2.api.repositories")
local spinner = require("atlas.ui.components.spinner")
local footer = require("atlas.ui.components.footer")

local detail_handle = nil
local readme_handle = nil

local panel_spinner = spinner.create({
	interval_ms = 120,
	on_tick = function()
		local detail_loading = panel_state.current_repo_detail == "loading"
		local readme_loading = panel_state.current_repo_readme == "loading"
		if not detail_loading and not readme_loading then
			panel_spinner:stop()
			return
		end

		if panel_state.current_tab ~= "overview" then
			return
		end

		require("atlas.bitbucketv2.panel.init").refresh()
	end,
})

local function cancel_handles()
	if detail_handle ~= nil and detail_handle.cancel then
		pcall(detail_handle.cancel)
	end
	detail_handle = nil

	if readme_handle ~= nil and readme_handle.cancel then
		pcall(readme_handle.cancel)
	end
	readme_handle = nil
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

---@param repo table|nil
function M.show(repo)
	local prev_name = state.repo and state.repo.full_name or nil
	local next_name = repo and repo.full_name or nil
	local same_repo = prev_name == next_name

	if not same_repo then
		cancel_handles()
	end

	local detail_loading = panel_state.current_repo_detail == "loading"
	local readme_loading = panel_state.current_repo_readme == "loading"
	if same_repo and (detail_loading or readme_loading) then
		state.repo = repo
		state.line_map = {}
		start_spinner()
		require("atlas.bitbucketv2.panel.init").refresh()
		return
	end

	stop_spinner()
	state.repo = repo
	state.line_map = {}

	if repo == nil then
		panel_state.set_repo_detail(nil)
		panel_state.set_repo_readme(nil)
		return
	end

	if
		same_repo
		and panel_state.current_repo_detail ~= nil
		and panel_state.current_repo_detail ~= "loading"
		and panel_state.current_repo_readme ~= nil
		and panel_state.current_repo_readme ~= "loading"
	then
		return
	end

	local workspace = tostring(repo.workspace or "")
	local repo_slug = tostring(repo.repo_slug or repo.slug or "")

	if workspace == "" or repo_slug == "" then
		panel_state.set_repo_detail(nil)
		panel_state.set_repo_readme(nil)
		footer.notify("error", "Missing repository info")
		return
	end

	-- Fetch detail
	panel_state.set_repo_detail_loading()
	start_spinner()

	detail_handle = repositories.fetch_detail(workspace, repo_slug, {}, function(detail, err)
		detail_handle = nil

		if state.repo == nil or state.repo.full_name ~= next_name then
			return
		end

		if err ~= nil then
			panel_state.set_repo_detail(nil)
			footer.notify("error", "Failed to load repo detail: " .. tostring(err))
		else
			panel_state.set_repo_detail(detail)

			local ref = (detail.mainbranch or {}).name or "main"
			local readme_path = tostring(repo.readme or "README.md")

			panel_state.set_repo_readme_loading()

			readme_handle = repositories.fetch_readme(workspace, repo_slug, ref, readme_path, {}, function(readme, readme_err)
				readme_handle = nil

				if state.repo == nil or state.repo.full_name ~= next_name then
					return
				end

				if readme_err ~= nil then
					panel_state.set_repo_readme(nil)
				else
					panel_state.set_repo_readme(readme)
				end

				stop_spinner()
				footer.notify("success", "Repository loaded", 1200)
				require("atlas.bitbucketv2.panel.init").refresh()
			end)
		end

		require("atlas.bitbucketv2.panel.init").refresh()
	end)

	footer.notify("loading", "Loading repository...")
	require("atlas.bitbucketv2.panel.init").refresh()
end

function M.refresh()
	if state.repo == nil then
		return
	end

	cancel_handles()
	M.show(state.repo)
end

function M.reset()
	cancel_handles()
	stop_spinner()
	state.reset()
end

function M.deactivate()
	stop_spinner()
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
