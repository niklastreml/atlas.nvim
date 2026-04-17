---@class MockTab : PullsPanelTabModule
local M = {}

local utils = require("atlas.ui.shared.utils")
local icons = require("atlas.ui.shared.icons")

local PADDING_X = 1
local PADDING = string.rep(" ", PADDING_X)

---@param pr PullRequest
---@param width integer
---@return string[], table[], table<integer, table>|nil
function M.render(pr, width)
	local lines = {}
	local spans = {}
	local content_width = math.max(10, width - (PADDING_X * 2))

	local title = icons.pulls_provider("mock", "provider") .. " Atlas Mock Provider"
	utils.push(lines, spans, title, "AtlasColumnHeader", PADDING_X)
	table.insert(lines, "")

	utils.push(lines, spans, "About", "AtlasColumnHeader", PADDING_X)
	local about = {
		"This is the built-in mock provider for atlas.nvim.",
		"It generates fake pull requests, reviewers, builds, and",
		"file changes so you can explore the UI without connecting",
		"to a real service like Bitbucket or GitHub.",
		"",
		"All data is randomized on each load. Nothing is persisted",
		"and no network requests are made.",
	}
	for _, line in ipairs(about) do
		local wrapped = utils.wrap_line(line, content_width)
		for _, chunk in ipairs(wrapped) do
			table.insert(lines, PADDING .. chunk)
		end
	end
	table.insert(lines, "")

	utils.push(lines, spans, "What it demonstrates", "AtlasColumnHeader", PADDING_X)
	local features = {
		{ icon = icons.general("success"), text = "Provider-based architecture", hl = "AtlasTextPositive" },
		{
			icon = icons.general("success"),
			text = "Async data fetching with loading spinners",
			hl = "AtlasTextPositive",
		},
		{ icon = icons.general("success"), text = "Tab navigation and per-tab state", hl = "AtlasTextPositive" },
		{ icon = icons.general("success"), text = "Reviewers grouped by approval status", hl = "AtlasTextPositive" },
		{ icon = icons.general("success"), text = "Build status with colored indicators", hl = "AtlasTextPositive" },
		{ icon = icons.general("success"), text = "Diffstat with file change summary", hl = "AtlasTextPositive" },
		{ icon = icons.general("success"), text = "Actions menu (approve, merge, decline)", hl = "AtlasTextPositive" },
		{ icon = icons.general("success"), text = "Header, chips, and panel customization", hl = "AtlasTextPositive" },
	}
	for _, f in ipairs(features) do
		utils.push(lines, spans, string.format("%s %s", f.icon, f.text), f.hl, PADDING_X)
	end
	table.insert(lines, "")

	utils.push(lines, spans, "Current PR", "AtlasColumnHeader", PADDING_X)
	utils.push(lines, spans, string.format("ID:      %s", tostring(pr.id or "-")), "AtlasTextMuted", PADDING_X)
	utils.push(lines, spans, string.format("Repo:    %s", tostring(pr.repo_name or "-")), "AtlasTextMuted", PADDING_X)
	utils.push(lines, spans, string.format("State:   %s", tostring(pr.state or "-")), "AtlasTextMuted", PADDING_X)
	utils.push(
		lines,
		spans,
		string.format("Author:  %s", tostring(pr.author and pr.author.name or "-")),
		"AtlasTextMuted",
		PADDING_X
	)
	utils.push(
		lines,
		spans,
		string.format("Branch:  %s", tostring(pr.source and pr.source.branch or "-")),
		"AtlasTextMuted",
		PADDING_X
	)
	table.insert(lines, "")

	utils.push(lines, spans, "Getting started", "AtlasColumnHeader", PADDING_X)
	local hint = {
		"To use a real provider, configure atlas.nvim with your",
		"Bitbucket or GitHub credentials. See :checkhealth atlas",
		"for setup status and the README for configuration details.",
	}
	for _, line in ipairs(hint) do
		local wrapped = utils.wrap_line(line, content_width)
		for _, chunk in ipairs(wrapped) do
			table.insert(lines, PADDING .. chunk)
		end
	end

	return lines, spans, nil
end

return M
