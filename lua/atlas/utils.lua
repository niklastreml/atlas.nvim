local M = {}

local _cached_version = nil

function M.append_block(lines, spans, block)
	local base = #lines
	for _, line in ipairs(block.lines or {}) do
		table.insert(lines, line)
	end
	for _, span in ipairs(block.highlights or {}) do
		table.insert(spans, {
			line = base + span.line,
			start_col = span.start_col,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end
end

function M.get_version()
	if _cached_version then
		return _cached_version
	end

	local ok, version = pcall(function()
		return vim.fn.system(
			"git -C " .. vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h:h") .. " describe --tags --abrev=0"
		)
	end)

	if ok then
		version = version:gsub("%s+", "")
		_cached_version = version
	end

	_cached_version = "dev"
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

return M
