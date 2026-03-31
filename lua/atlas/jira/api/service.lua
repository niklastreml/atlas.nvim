local M = {}

local config = require("atlas.config")
local http = require("atlas.core.http")
local memory_cache = require("atlas.core.memory_cache")
local cache = require("atlas.core.cache")
local logger = require("atlas.core.logger")

local API_PATH = "/rest/api/3"

---@return string, string, string|nil
function M.get_auth()
	local jira = (config.options and config.options.jira) or {}
	local base_url = jira.base_url
	local email = jira.email
	local token = jira.token

	if not base_url or base_url == "" or not email or email == "" or not token or token == "" then
		return "", "", "Missing Jira credentials in config (jira.base_url, jira.email, jira.token)"
	end

	return base_url, email, nil
end

---@return table<string, string>
function M.build_headers()
	local jira = (config.options and config.options.jira) or {}
	local email = jira.email or ""
	local token = jira.token or ""
	local auth = vim.base64.encode(string.format("%s:%s", email, token))
	return {
		Authorization = "Basic " .. auth,
		["Content-Type"] = "application/json",
		Accept = "application/json",
	}
end

---@return string
function M.base_url()
	local jira = (config.options and config.options.jira) or {}
	return tostring(jira.base_url or "")
end

---@param endpoint string
---@return string
function M.url(endpoint)
	return M.base_url() .. API_PATH .. endpoint
end

---@return number
function M.cache_ttl()
	local jira = (config.options and config.options.jira) or {}
	return tonumber(jira.cache_ttl) or 300
end

function M.clear_memory_cache()
	memory_cache.clear_all()
end

---@param method string
---@param endpoint string
---@param data table|nil
---@param on_done fun(result: table|nil, err: string|nil)
---@return { job_id: integer, cancel: fun() }|nil
function M.request(method, endpoint, data, on_done)
	local _, _, auth_err = M.get_auth()
	if auth_err then
		logger.logerror("Jira auth missing", { error = auth_err })
		on_done(nil, auth_err)
		return nil
	end

	local url = M.url(endpoint)
	local headers = M.build_headers()
	local payload = nil
	if type(data) == "table" then
		payload = vim.fn.json_encode(data)
	end

	return http.curl_request(method, url, headers, payload, function(result, err)
		if err then
			on_done(nil, err)
			return
		end

		if type(result) ~= "table" then
			on_done(nil, "Jira response is not a JSON object")
			return
		end

		if result.errorMessages or result.errors then
			local messages = {}
			for _, msg in ipairs(result.errorMessages or {}) do
				table.insert(messages, msg)
			end
			for k, v in pairs(result.errors or {}) do
				table.insert(messages, k .. ": " .. v)
			end
			if #messages > 0 then
				on_done(nil, table.concat(messages, "; "))
				return
			end
		end

		on_done(result, nil)
	end)
end

return M
