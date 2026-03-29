local M = {}

local utils = require("atlas.utils")
local icons = require("atlas.ui.icons")

---@param decision string
---@return string
local function decision_icon(decision)
	if decision == "approved" then
		return icons.entity("success")
	end
	if decision == "changes_requested" then
		return icons.entity("warning")
	end
	return icons.entity("pending")
end

---@param decision string
---@return string
local function decision_hl(decision)
	if decision == "approved" then
		return "AtlasTextPositive"
	end
	if decision == "changes_requested" then
		return "AtlasTextWarning"
	end
	return "AtlasTextMuted"
end

---@param pr table|nil
---@param detail BitbucketPRDetail|nil
---@return string[]
local function overview_lines(pr, detail)
	local lines = {}
	local spans = {}
	local description_text = ((pr or {}).rendered or {}).description
	description_text = (description_text or {}).raw
		or (pr or {}).description
		or ((pr or {}).summary or {}).raw
		or ""
	local description = utils.sanitize_markdown_lines(description_text)

	for _, line in ipairs(description) do
		table.insert(lines, line)
	end

	table.insert(lines, "")
	table.insert(lines, "Reviewers")

	local decisions = (detail and detail.decisions) or {}
	if #decisions == 0 then
		table.insert(lines, "- no reviewer data yet")
		return lines, spans
	end

	for _, d in ipairs(decisions) do
		local name = d.name
		if name == nil or name == "" then
			name = (d.nickname and d.nickname ~= "") and d.nickname or "Unknown"
		end
		local icon = decision_icon(d.decision)
		table.insert(lines, string.format("%s %s", icon, name))
		table.insert(spans, {
			line = #lines - 1,
			start_col = 0,
			end_col = #icon,
			hl_group = decision_hl(d.decision),
		})
	end

	return lines, spans
end

---@param tab "overview"|"commits"|"files"
---@param pr table|nil
---@param detail BitbucketPRDetail|nil
---@return string[] lines
---@return table[] spans
function M.render(tab, pr, detail)
	local spans = {}
	if tab == "overview" then
		return overview_lines(pr, detail)
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
