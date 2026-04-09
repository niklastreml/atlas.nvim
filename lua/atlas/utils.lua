local M = {}

local _cached_version = nil

function M.append_block(lines, spans, block)
	local base = #lines
	for _, line in ipairs(block.lines or {}) do
		table.insert(lines, line)
	end
	for _, span in ipairs(block.highlights or {}) do
		if type(span) == "table" and span.line_hl_group ~= nil then
			table.insert(spans, {
				line = base + span.line,
				line_hl_group = span.line_hl_group,
			})
		else
			table.insert(spans, {
				line = base + span.line,
				start_col = span.start_col,
				end_col = span.end_col,
				hl_group = span.hl_group,
			})
		end
	end
end

function M.get_version()
	if _cached_version then
		return _cached_version
	end

	local ok, version = pcall(function()
		return vim.fn.system(
			"git -C " .. vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h:h") .. " describe --tags --abbrev=0"
		)
	end)

	if ok and type(version) == "string" and version ~= "" then
		_cached_version = version:gsub("%s+", "")
	else
		_cached_version = "dev"
	end

	return _cached_version
end

function M.relative_time(iso)
	if type(iso) ~= "string" or iso == "" then
		return "-"
	end

	local base = iso:match("^(%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d)")
	if not base then
		return "-"
	end

	local then_epoch = vim.fn.strptime("%Y-%m-%dT%H:%M:%S", base)
	if then_epoch <= 0 then
		return "-"
	end

	local delta = os.time() - then_epoch
	if delta < 0 then
		delta = 0
	end

	if delta < 5 then
		return "now"
	end
	if delta < 60 then
		return string.format("%ds", delta)
	end

	local minutes = math.floor(delta / 60)
	if minutes < 60 then
		return string.format("%dm", minutes)
	end

	local hours = math.floor(minutes / 60)
	if hours < 24 then
		return string.format("%dh", hours)
	end

	local days = math.floor(hours / 24)
	if days < 7 then
		return string.format("%dd", days)
	end

	local weeks = math.floor(days / 7)
	if weeks < 5 then
		return string.format("%dw", weeks)
	end

	local months = math.floor(days / 30)
	if months < 12 then
		return string.format("%dmo", months)
	end

	local years = math.floor(days / 365)
	return string.format("%dy", years)
end

---@param iso string|nil
---@return string
function M.relative_time_text(iso)
	local rel = M.relative_time(iso)
	if rel == "-" then
		return "-"
	end
	if rel == "now" then
		return "just now"
	end

	local n, unit = rel:match("^(%d+)(%a+)$")
	if n == nil or unit == nil then
		return rel
	end

	n = tonumber(n) or 0
	local labels = {
		s = "second",
		m = "minute",
		h = "hour",
		d = "day",
		w = "week",
		mo = "month",
		y = "year",
	}
	local base = labels[unit] or unit
	local suffix = n == 1 and "" or "s"
	return string.format("%d %s%s ago", n, base, suffix)
end

---@param iso string|nil
---@return string
function M.format_date(iso)
	if type(iso) ~= "string" or iso == "" then
		return ""
	end

	local ymd = iso:match("^(%d%d%d%d%-%d%d%-%d%d)")
	if ymd ~= nil then
		return ymd
	end

	return ""
end

---@param bytes number|string|nil
---@return string
function M.human_size(bytes)
	local n = tonumber(bytes) or 0
	if n < 0 then
		n = 0
	end

	local units = { "B", "KB", "MB", "GB", "TB" }
	local i = 1
	while n >= 1024 and i < #units do
		n = n / 1024
		i = i + 1
	end

	if i == 1 then
		return string.format("%d %s", math.floor(n), units[i])
	end

	return string.format("%.1f %s", n, units[i])
end

---@param seconds number|string|nil
---@return string
function M.human_duration(seconds)
	local total = tonumber(seconds)
	if total == nil then
		return ""
	end

	if total < 0 then
		total = 0
	end

	local minutes = math.floor(total / 60)
	if minutes < 60 then
		return string.format("%dm", minutes)
	end

	local hours = math.floor(minutes / 60)
	local rem_minutes = minutes % 60
	if hours < 24 then
		if rem_minutes == 0 then
			return string.format("%dh", hours)
		end
		return string.format("%dh %dm", hours, rem_minutes)
	end

	local days = math.floor(hours / 24)
	local rem_hours = hours % 24
	if rem_hours == 0 then
		return string.format("%dd", days)
	end
	return string.format("%dd %dh", days, rem_hours)
end

---@param value any
---@return string
function M.encode_pretty_json(value)
	local ok, encoded = pcall(vim.json.encode, value, { indent = "  " })
	if ok and type(encoded) == "string" and encoded ~= "" then
		return encoded
	end

	local fallback_ok, fallback = pcall(vim.fn.json_encode, value)
	if fallback_ok and type(fallback) == "string" and fallback ~= "" then
		return fallback
	end

	return "{}"
end

---@param text string|nil
---@return string[]
function M.sanitize_lines(text)
	if type(text) ~= "string" or text == "" then
		return { "-" }
	end

	local out = {}
	text = text:gsub("\r\n", "\n")
	for line in (text .. "\n"):gmatch("(.-)\n") do
		table.insert(out, line)
	end

	if #out == 0 then
		return { "-" }
	end

	return out
end

local strwidth = vim.api.nvim_strwidth
local strcharpart = vim.fn.strcharpart
local strchars = vim.fn.strchars

---@param str string
---@param max_dw integer
---@param from_start? boolean
---@return string
function M.truncate(str, max_dw, from_start)
	local ellipsis = "…"
	if max_dw < 1 then
		return ellipsis
	end
	if strwidth(str) <= max_dw then
		return str
	end

	local nchars = strchars(str)
	if from_start then
		for i = 1, nchars do
			local tail = strcharpart(str, i)
			if strwidth(tail) <= max_dw - 1 then
				return ellipsis .. tail
			end
		end
		return ellipsis
	end

	for i = nchars - 1, 0, -1 do
		local head = strcharpart(str, 0, i)
		if strwidth(head) <= max_dw - 1 then
			return head .. ellipsis
		end
	end
	return ellipsis
end

---@param text string
---@param max_dw integer
---@return string[]
function M.wrap_line(text, max_dw)
	if max_dw < 2 or strwidth(text) <= max_dw then
		return { text }
	end

	local result = {}
	local remaining = text
	while remaining ~= "" do
		if strwidth(remaining) <= max_dw then
			result[#result + 1] = remaining
			break
		end

		local nchars = strchars(remaining)
		local cut = nchars
		for i = nchars - 1, 1, -1 do
			if strwidth(strcharpart(remaining, 0, i)) <= max_dw then
				cut = i
				break
			end
		end

		local last_space = nil
		local half = math.floor(cut * 0.5)
		for i = cut, half, -1 do
			if strcharpart(remaining, i - 1, 1) == " " then
				last_space = i
				break
			end
		end

		if last_space then
			result[#result + 1] = strcharpart(remaining, 0, last_space - 1)
			remaining = strcharpart(remaining, last_space)
		else
			result[#result + 1] = strcharpart(remaining, 0, cut)
			remaining = strcharpart(remaining, cut)
		end
	end

	return result
end

return M
