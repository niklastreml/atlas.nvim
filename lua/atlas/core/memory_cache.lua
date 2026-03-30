local M = {}

---@class MemoryCacheEntry
---@field value any
---@field expires_at number|nil

---@type table<string, MemoryCacheEntry>
local store = {}

---@param key string
---@param value any
---@param ttl number|nil
function M.set(key, value, ttl)
	local expires_at = nil
	if ttl ~= nil and ttl > 0 then
		expires_at = os.time() + ttl
	end

	store[key] = {
		value = value,
		expires_at = expires_at,
	}
end

---@param key string
---@return MemoryCacheEntry|nil
function M.get(key)
	local entry = store[key]
	if entry == nil then
		return nil
	end

	if entry.expires_at and os.time() > entry.expires_at then
		store[key] = nil
		return nil
	end

	return entry
end

---@param key string
function M.delete(key)
	store[key] = nil
end

function M.clear_all()
	store = {}
end

return M
