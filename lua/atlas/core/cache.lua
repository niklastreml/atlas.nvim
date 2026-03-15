---TODO: Basic memory cache. Migrate to disk-based cache later
local M = {}

---@class CacheEntry
---@field value any
---@field expires_at number | nil

---@type table<string, CacheEntry>
local memory_cache = {}

---@param key string
---@param value any
---@param ttl number Time to live in seconds
function M.set(key, value, ttl)
	local expires_at = os.time() + ttl
	memory_cache[key] = { value = value, expires_at = expires_at }
end

--- @param key string
---@return CacheEntry|nil
function M.get(key)
	local entry = memory_cache[key]
	if not entry then
		return nil
	end

	if entry.expires_at and os.time() > entry.expires_at then
		memory_cache[key] = nil
		return nil
	end

	return entry
end

return M
