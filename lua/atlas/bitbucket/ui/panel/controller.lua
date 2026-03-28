local M = {}

local panel_state = require("atlas.bitbucket.ui.panel.state")
local renderer = require("atlas.bitbucket.ui.panel.renderer")

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
end

---@param pr_key string
---@param request_id number
function M.fetch_activity(pr_key, request_id) end

---@param pr_key string
---@param request_id number
function M.fetch_builds(pr_key, request_id) end

---@param pr_key string
---@param request_id number
function M.fetch_reviewers(pr_key, request_id) end

function M.refresh()
	renderer.render()
end

return M
