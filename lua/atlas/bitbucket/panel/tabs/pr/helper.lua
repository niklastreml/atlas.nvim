local M = {}

---@param statuses BitbucketPRStatuses|nil
---@return "successful"|"failed"|"inprogress"|"stopped"|"unknown"
local function aggregate_status(statuses)
	if type(statuses) ~= "table" or type(statuses.entries) ~= "table" then
		return "unknown"
	end

	local has_success = false
	local has_stopped = false
	for _, entry in ipairs(statuses.entries) do
		local s = tostring(entry.state or "UNKNOWN")
		if s == "FAILED" then
			return "failed"
		end
		if s == "INPROGRESS" then
			return "inprogress"
		end
		if s == "STOPPED" then
			has_stopped = true
		elseif s == "SUCCESSFUL" then
			has_success = true
		end
	end

	if has_stopped then
		return "stopped"
	end
	if has_success then
		return "successful"
	end
	return "unknown"
end

---@param status string|nil
---@return string
local function status_label(status)
	local s = tostring(status or ""):lower()
	if s == "" then
		return "Unknown"
	end
	return s:sub(1, 1):upper() .. s:sub(2)
end

---@param statuses BitbucketPRStatuses|nil
---@return string|nil
local function first_status_url(statuses)
	if type(statuses) ~= "table" or type(statuses.entries) ~= "table" then
		return nil
	end

	for _, entry in ipairs(statuses.entries) do
		local url = tostring(entry.url or "")
		if url ~= "" then
			return url
		end
	end

	return nil
end

M.statuses = {
	aggregate = aggregate_status,
	label = status_label,
	first_url = first_status_url,
}

return M
