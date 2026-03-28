local M = {}

---@param item table
function M.on_select(item) end

---@param issue_key string
---@param request_id number
function M.fetch_comments(issue_key, request_id) end

---@param issue_key string
---@param request_id number
function M.fetch_transitions(issue_key, request_id) end

---@param issue_key string
---@param request_id number
function M.fetch_linked(issue_key, request_id) end

function M.refresh() end

return M
