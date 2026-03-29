local M = {}

local utils = require("atlas.utils")

---@param tab "overview"|"commits"|"files"
---@param pr table|nil
---@return string[] lines
---@return table[] spans
function M.render(tab, pr)
	local spans = {}
	if tab == "overview" then
		local description_text = ((pr or {}).rendered or {}).description
		description_text = (description_text or {}).raw
			or (pr or {}).description
			or ((pr or {}).summary or {}).raw
			or ""
		local lines = utils.sanitize_markdown_lines(description_text)
		return lines, spans
	end
	if tab == "commits" then
		return {
			"Commits content placeholder.",
			"",
			"Later: fetch commits and render list.",
		}, spans
	end
	return {
		"File changes content placeholder.",
		"",
		"Later: fetch diffstat/files and render list.",
	}, spans
end
return M
