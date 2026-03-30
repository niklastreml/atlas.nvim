local M = {}

local service = require("atlas.bitbucket.api.service")
local state = require("atlas.bitbucket.ui.panel.repository.state")
local renderer = require("atlas.bitbucket.ui.panel.repository.renderer")
local spinner = require("atlas.ui.components.spinner")
local footer = require("atlas.ui.components.footer")
local layout = require("atlas.ui.layout")

local active_handle = nil
local active_readme_handle = nil
local detail_spinner

local TAB_ORDER = {
	"overview",
	"branches",
	"tags",
}

detail_spinner = spinner.create({
	interval_ms = 120,
		on_tick = function()
		local repo = state.current_repo
		local is_detail_loading = state.current_detail == "loading"
		local is_readme_loading = state.current_readme == "loading"
		local is_branches_loading = state.current_branches == "loading"
		local is_tags_loading = state.current_tags == "loading"
		if repo == nil or (not is_detail_loading and not is_readme_loading and not is_branches_loading and not is_tags_loading) then
			detail_spinner:stop()
			return
		end
		renderer.render(repo)
	end,
})

local function cancel_handle()
	if active_handle ~= nil and active_handle.cancel then
		pcall(active_handle.cancel)
	end
	active_handle = nil
end

local function cancel_readme_handle()
	if active_readme_handle ~= nil and active_readme_handle.cancel then
		pcall(active_readme_handle.cancel)
	end
	active_readme_handle = nil
end

local function start_spinner()
	if detail_spinner:is_running() then
		return
	end
	detail_spinner:start()
end

local function stop_spinner()
	detail_spinner:stop()
end

---@param tab string
local function apply_tab_buffer_mode(tab)
	local buf = layout.buf_id("detail")
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	if tab == "overview" then
		vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })
	else
		vim.api.nvim_set_option_value("filetype", "atlas-detail", { buf = buf })
	end
end

---@param repo table
---@param detail BitbucketRepositoryDetail
---@param on_done fun(err: string|nil)|nil
local function fetch_readme(repo, detail, on_done)
	local workspace = tostring(repo.workspace or "")
	local repo_slug = tostring(repo.repo_slug or "")
	local ref = tostring((detail.mainbranch or {}).name or "")
	if workspace == "" or repo_slug == "" or ref == "" then
		if type(on_done) == "function" then
			on_done("Missing repository readme parameters")
		end
		return
	end

	state.set_current_readme_loading()
	renderer.render(repo)
	cancel_readme_handle()
	active_readme_handle = service.fetch_repository_readme(
		workspace,
		repo_slug,
		ref,
		repo.readme,
		{ force_load = false },
		function(text, err)
			active_readme_handle = nil

			local current = state.current_repo
			if current == nil then
				return
			end
			if tostring(current.workspace or "") ~= workspace or tostring(current.repo_slug or "") ~= repo_slug then
				return
			end

			if err ~= nil then
				state.set_current_readme(nil)
				renderer.render(current)
				if type(on_done) == "function" then
					on_done(tostring(err))
				end
				return
			end

			state.set_current_readme(tostring(text or ""))
			renderer.render(current)
			if type(on_done) == "function" then
				on_done(nil)
			end
		end
	)
end

---@param repo table|nil
---@param on_done fun(err: string|nil)|nil
local function fetch_detail(repo, on_done)
	if repo == nil then
		return
	end

	local workspace = tostring(repo.workspace or "")
	local repo_slug = tostring(repo.repo_slug or "")
	if workspace == "" or repo_slug == "" then
		return
	end

	state.set_current_detail_loading()

	cancel_handle()
	active_handle = service.fetch_repository_detail(workspace, repo_slug, { force_load = false }, function(detail, err)
		active_handle = nil

		local current = state.current_repo
		if current == nil then
			return
		end
		if tostring(current.workspace or "") ~= workspace or tostring(current.repo_slug or "") ~= repo_slug then
			return
		end

		if err ~= nil then
			state.set_current_detail(nil)
			if type(on_done) == "function" then
				on_done(tostring(err))
			end
			return
		end

		state.set_current_detail(detail)
		if type(on_done) == "function" then
			on_done(nil)
		end
	end)
end

---@param repo table|nil
function M.on_select(repo)
	cancel_handle()
	cancel_readme_handle()
	stop_spinner()
	state.set_current(repo)
	if repo ~= nil then
		M.select_tab("overview")
	else
		renderer.render({})
	end
end

function M.refresh()
	local repo = state.current_repo
	if repo ~= nil then
		renderer.render(repo)
	end
end

---@param tab "overview"|"branches"|"tags"
function M.select_tab(tab)
	state.set_current_tab(tab)
	apply_tab_buffer_mode(tab)
	M.refresh()

	local repo = state.current_repo
	if repo == nil then
		return
	end

	if state.current_detail == nil then
		start_spinner()
		footer.notify("loading", "Loading repository details...")
		fetch_detail(repo, function(err)
			stop_spinner()
			if err ~= nil then
				footer.notify("error", string.format("Failed loading repository details: %s", tostring(err)))
				M.refresh()
				return
			end
			footer.notify("success", "Repository details loaded", 1200)
			M.select_tab(state.current_tab)
		end)
		return
	end

	if tab == "overview" then
		local detail = state.current_detail
		if state.current_readme == nil and type(detail) == "table" then
			start_spinner()
			footer.notify("loading", "Loading readme...")
			fetch_readme(repo, detail, function(err)
				stop_spinner()
				if err ~= nil then
					footer.notify("error", string.format("Failed loading readme: %s", tostring(err)))
					return
				end
				footer.notify("success", "Readme loaded", 1200)
			end)
		end
	elseif tab == "branches" then
		local detail = state.current_detail
		if state.current_branches == nil and type(detail) == "table" then
			state.set_current_branches_loading()
			M.refresh()
			start_spinner()
			footer.notify("loading", "Loading branches...")
			local branches_url = tostring((((detail.links or {}).branches or {}).href) or "")
			service.fetch_repository_branches(branches_url, { force_load = false }, function(branches, err)
				stop_spinner()
				if err ~= nil then
					state.set_current_branches(nil)
					M.refresh()
					footer.notify("error", string.format("Failed loading branches: %s", tostring(err)))
					return
				end
				state.set_current_branches(branches)
				M.refresh()
				footer.notify("success", "Branches loaded", 1200)
			end)
		end
	elseif tab == "tags" then
		local detail = state.current_detail
		if state.current_tags == nil and type(detail) == "table" then
			state.set_current_tags_loading()
			M.refresh()
			start_spinner()
			footer.notify("loading", "Loading tags...")
			local tags_url = tostring((((detail.links or {}).tags or {}).href) or "")
			service.fetch_repository_tags(tags_url, { force_load = false }, function(tags, err)
				stop_spinner()
				if err ~= nil then
					state.set_current_tags(nil)
					M.refresh()
					footer.notify("error", string.format("Failed loading tags: %s", tostring(err)))
					return
				end
				state.set_current_tags(tags)
				M.refresh()
				footer.notify("success", "Tags loaded", 1200)
			end)
		end
	end
end

function M.next_tab()
	local idx = 1
	for i, key in ipairs(TAB_ORDER) do
		if key == state.current_tab then
			idx = i
			break
		end
	end

	local next_idx = idx + 1
	if next_idx > #TAB_ORDER then
		next_idx = 1
	end

	M.select_tab(TAB_ORDER[next_idx])
end

function M.prev_tab()
	local idx = 1
	for i, key in ipairs(TAB_ORDER) do
		if key == state.current_tab then
			idx = i
			break
		end
	end

	local prev_idx = idx - 1
	if prev_idx < 1 then
		prev_idx = #TAB_ORDER
	end

	M.select_tab(TAB_ORDER[prev_idx])
end

return M
