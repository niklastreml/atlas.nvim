local M = {}

local service = require("atlas.bitbucket.api.service")
local panel_state = require("atlas.bitbucket.ui.panel.state")
local renderer = require("atlas.bitbucket.ui.panel.renderer")

local TAB_ORDER = {
	"overview",
	"commits",
	"files",
}

---@param item table
function M.on_select(item)
	local pr = nil
	if type(item) == "table" then
		if type(item.pr) == "table" then
			pr = item.pr
		elseif item.kind == "pr" then
			pr = item
		end
	end

	panel_state.set_current(pr)
	renderer.render()

	if pr ~= nil then
		M.fetch_reviewers(tostring(pr.id or ""), 0)
	end
end

---@param tab string
function M.select_tab(tab)
	panel_state.set_current_tab(tab)
	renderer.render()

	-- TODO: Later API hooks:
	-- if tab == panel_state.tabs.COMMITS then fetch commits end
	-- if tab == panel_state.tabs.FILES then fetch file changes end
end

function M.next_tab()
	local idx = 1
	for i, key in ipairs(TAB_ORDER) do
		if key == panel_state.current_tab then
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
		if key == panel_state.current_tab then
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

---@param pr_key string
---@param request_id number
function M.fetch_activity(pr_key, request_id) end

---@param pr_key string
---@param request_id number
function M.fetch_builds(pr_key, request_id) end

---@param pr_key string
---@param request_id number
function M.fetch_reviewers(pr_key, request_id)
	local _ = request_id
	local pr = panel_state.current_pr
	if pr == nil then
		return
	end

	if tostring(pr.id or "") ~= tostring(pr_key or "") then
		return
	end

	local full_name = ((pr.repo or {}).name) or ""
	local workspace, repo = full_name:match("^([^/]+)/(.+)$")
	if workspace == nil or repo == nil then
		return
	end

	service.fetch_pullrequest_detail(workspace, repo, pr.id, { force_load = false }, function(detail, err)
		if err ~= nil then
			return
		end

		if tostring(((panel_state.current_pr or {}).id) or "") ~= tostring(pr_key or "") then
			return
		end

		panel_state.set_current_detail(detail)
		renderer.render()
	end)
end

function M.refresh()
	renderer.render()
end

return M
