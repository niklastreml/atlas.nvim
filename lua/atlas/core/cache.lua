local M = {}

---@class CacheEntry
---@field value any
---@field expires_at number | nil

local cache_root = vim.fn.stdpath("cache") .. "/atlas/cache"

local function ensure_cache_dir()
	if vim.fn.isdirectory(cache_root) == 0 then
		vim.fn.mkdir(cache_root, "p")
	end
end

---@param key string
---@return string
local function key_to_path(key)
	local hash = vim.fn.sha256(key)
	return string.format("%s/%s.json", cache_root, hash)
end

---@param path string
---@return CacheEntry|nil
local function read_entry(path)
	if vim.fn.filereadable(path) == 0 then
		return nil
	end

	local lines = vim.fn.readfile(path)
	if not lines or #lines == 0 then
		return nil
	end

	local raw = table.concat(lines, "\n")
	local ok, decoded = pcall(vim.fn.json_decode, raw)
	if not ok or type(decoded) ~= "table" then
		return nil
	end

	return decoded
end

---@param key string
---@param value any
---@param ttl number|nil
function M.set(key, value, ttl)
	ensure_cache_dir()

	local expires_at = nil
	if ttl ~= nil and ttl > 0 then
		expires_at = os.time() + ttl
	end

	local entry = {
		value = value,
		expires_at = expires_at,
	}

	local encoded = vim.json.encode(entry)
	vim.fn.writefile({ encoded }, key_to_path(key))
end

---@param key string
---@return CacheEntry|nil
function M.get(key)
	ensure_cache_dir()

	local path = key_to_path(key)
	local entry = read_entry(path)
	if not entry then
		return nil
	end

	if entry.expires_at and os.time() > entry.expires_at then
		pcall(vim.fn.delete, path)
		return nil
	end

	return entry
end

---@param key string
function M.delete(key)
	pcall(vim.fn.delete, key_to_path(key))
end

function M.clear_all()
	if vim.fn.isdirectory(cache_root) == 1 then
		pcall(vim.fn.delete, cache_root, "rf")
	end
end

return M
