local M = {}

---@class ActiveRequest
---@field id integer
---@field cancel fun()|nil

---@type table<string, ActiveRequest>
local active = {}

---@param scope string
---@return integer request_id
function M.begin(scope)
	local prev = active[scope]
	if prev and prev.cancel then
		pcall(prev.cancel)
	end

	local next_id = (prev and prev.id or 0) + 1
	active[scope] = { id = next_id, cancel = nil }
	return next_id
end

---@param scope string
---@param request_id integer
---@param cancel_fn fun()|nil
function M.attach_cancel(scope, request_id, cancel_fn)
	local req = active[scope]
	if req and req.id == request_id then
		req.cancel = cancel_fn
	end
end

---@param scope string
---@param request_id integer
---@return boolean
function M.is_latest(scope, request_id)
	local cur = active[scope]
	return cur ~= nil and cur.id == request_id
end

---@param scope string
---@param request_id integer
function M.finish(scope, request_id)
	local cur = active[scope]
	if cur and cur.id == request_id then
		active[scope] = nil
	end
end

function M.cancel(scope)
	local req = active[scope]
	if req and req.cancel then
		pcall(req.cancel)
	end

	active[scope] = nil
end

return M
