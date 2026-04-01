local M = {}

---@param issue JiraIssue
---@param width integer
---@return string[]
---@return table[]
function M.render(issue, width)
	local key = issue and issue.key or ""
	local title = issue and issue.summary or ""
	local line1 = key ~= "" and (" " .. key) or ""
	local line2 = title ~= "" and (" " .. title) or ""

	if width and width > 0 then
		if vim.fn.strdisplaywidth(line1) > width then
			line1 = vim.fn.strcharpart(line1, 0, math.max(0, width - 1)) .. "…"
		end
		if vim.fn.strdisplaywidth(line2) > width then
			line2 = vim.fn.strcharpart(line2, 0, math.max(0, width - 1)) .. "…"
		end
	end

	local lines = { line1, line2 }
	local spans = {}
	if key ~= "" then
		table.insert(spans, {
			line = 0,
			start_col = 1,
			end_col = 1 + #key,
			hl_group = "AtlasJiraKey",
		})
	end
	if title ~= "" then
		table.insert(spans, {
			line = 1,
			start_col = 1,
			end_col = #lines[2],
			hl_group = "AtlasJiraTitle",
		})
	end

	return lines, spans
end

return M
