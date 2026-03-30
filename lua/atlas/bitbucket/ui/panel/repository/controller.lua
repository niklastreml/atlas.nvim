local M = {}

local service = require("atlas.bitbucket.api.service")
local state = require("atlas.bitbucket.ui.panel.repository.state")
local renderer = require("atlas.bitbucket.ui.panel.repository.renderer")
local spinner = require("atlas.ui.components.spinner")
local footer = require("atlas.ui.components.footer")

local active_handle = nil
local detail_spinner

detail_spinner = spinner.create({
	interval_ms = 120,
	on_tick = function()
		local repo = state.current_repo
		if type(repo) ~= "table" or state.current_detail ~= "loading" then
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

local function start_spinner()
	if detail_spinner:is_running() then
		return
	end
	detail_spinner:start()
end

local function stop_spinner()
	detail_spinner:stop()
end

---@param repo table|nil
local function fetch_detail(repo)
	if type(repo) ~= "table" then
		return
	end

	local workspace = tostring(repo.workspace or "")
	local repo_slug = tostring(repo.repo_slug or "")
	if workspace == "" or repo_slug == "" then
		return
	end

	state.set_current_detail_loading()
	renderer.render(repo)
	start_spinner()
	footer.notify("loading", "Loading repository details...")

	cancel_handle()
	active_handle = service.fetch_repository_detail(workspace, repo_slug, { force_load = false }, function(detail, err)
		active_handle = nil

		local current = state.current_repo
		if type(current) ~= "table" then
			return
		end
		if tostring(current.workspace or "") ~= workspace or tostring(current.repo_slug or "") ~= repo_slug then
			return
		end

		if err ~= nil then
			stop_spinner()
			state.set_current_detail(nil)
			renderer.render(current)
			footer.notify("error", string.format("Failed loading repository details: %s", tostring(err)))
			return
		end

		stop_spinner()
		state.set_current_detail(detail)
		renderer.render(current)
		footer.notify("success", "Repository details loaded", 1200)
	end)
end

---@param repo table|nil
function M.on_select(repo)
	cancel_handle()
	stop_spinner()
	state.set_current(repo)
	state.set_current_tab("overview")
	renderer.render(repo or {})
	fetch_detail(repo)
end

function M.refresh()
	local repo = state.current_repo
	if type(repo) == "table" then
		renderer.render(repo)
		if state.current_detail == nil then
			fetch_detail(repo)
		end
	end
end

---@param tab "overview"|"branches"|"tags"|"commits"
function M.select_tab(tab)
	state.set_current_tab(tab)
	M.refresh()
end

return M
