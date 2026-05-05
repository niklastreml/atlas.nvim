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

	-- Title
	local title = icons.pulls_provider("mock", "provider") .. " Atlas.nvim"
	utils.push(lines, spans, title, "AtlasMockTheme", PADDING_X)
	table.insert(lines, "")

	-- Intro
	local intro = {
		"A Neovim plugin for managing pull requests and issues",
		"without leaving your editor.",
		"",
		"This is the built-in mock provider. It generates fake data",
		"so you can explore the UI without connecting to a real",
		"service. No network requests are made.",
	}
	for _, line in ipairs(intro) do
		local wrapped = utils.wrap_line(line, content_width)
		for _, chunk in ipairs(wrapped) do
			table.insert(lines, PADDING .. chunk)
		end
	end
	table.insert(lines, "")

	-- Features
	utils.push(lines, spans, "Features", "AtlasColumnHeader", PADDING_X)
	local features = {
		"Multiple provider support (Bitbucket, GitHub, ...)",
		"PR tabs: overview, activity, comments, commits, files",
		"PR actions: merge, approve, request changes, decline",
		"Comment workflows (create, reply, edit, delete)",
		"Async data fetching with loading spinners",
		"Customizable views, keymaps, and layouts",
		"Jira integration for issue management",
	}
	for _, f in ipairs(features) do
		local text = string.format("%s %s", icons.pulls_status("successful"), f)
		utils.push(lines, spans, text, "AtlasTextPositive", PADDING_X)
	end
	table.insert(lines, "")

	-- Commands
	utils.push(lines, spans, "Commands", "AtlasColumnHeader", PADDING_X)
	local commands = {
		{ cmd = ":AtlasPulls", desc = "Open pull request picker" },
		{ cmd = ":AtlasClearCache", desc = "Clear Atlas cache" },
		{ cmd = ":AtlasLogs", desc = "Toggle Atlas logs" },
	}
	for _, c in ipairs(commands) do
		local line = string.format("  %-20s %s", c.cmd, c.desc)
		table.insert(lines, PADDING .. line)
		table.insert(spans, {
			line = #lines - 1,
			start_col = PADDING_X + 2,
			end_col = PADDING_X + 2 + #c.cmd,
			hl_group = "AtlasMockTheme",
		})
		table.insert(spans, {
			line = #lines - 1,
			start_col = PADDING_X + 22,
			end_col = PADDING_X + 22 + #c.desc,
			hl_group = "AtlasTextMuted",
		})
	end
	table.insert(lines, "")

	-- Keymaps
	utils.push(lines, spans, "Keymaps", "AtlasColumnHeader", PADDING_X)
	local keymaps = {
		{ key = "q", desc = "Close Atlas / panel" },
		{ key = "p", desc = "Toggle detail panel" },
		{ key = "Tab / S-Tab", desc = "Next / previous panel tab" },
		{ key = "?", desc = "Toggle help popup" },
		{ key = "R", desc = "Refresh current view" },
		{ key = "A", desc = "Open actions menu" },
	}
	for _, k in ipairs(keymaps) do
		local line = string.format("  %-20s %s", k.key, k.desc)
		table.insert(lines, PADDING .. line)
		table.insert(spans, {
			line = #lines - 1,
			start_col = PADDING_X + 2,
			end_col = PADDING_X + 2 + #k.key,
			hl_group = "AtlasMockTheme",
		})
		table.insert(spans, {
			line = #lines - 1,
			start_col = PADDING_X + 22,
			end_col = PADDING_X + 22 + #k.desc,
			hl_group = "AtlasTextMuted",
		})
	end
	table.insert(lines, "")

	-- Getting started
	utils.push(lines, spans, "Getting started", "AtlasColumnHeader", PADDING_X)
	local getting_started = {
		"To use a real provider, configure atlas.nvim with your",
		"credentials in your Neovim config:",
		"",
		'  require("atlas").setup({',
		"    pulls = { provider = \"bitbucket\" },",
		"  })",
		"",
		"Run :checkhealth atlas to verify your setup.",
		"See the README for full configuration details.",
	}
	for _, line in ipairs(getting_started) do
		local wrapped = utils.wrap_line(line, content_width)
		for _, chunk in ipairs(wrapped) do
			table.insert(lines, PADDING .. chunk)
		end
	end

	return lines, spans, nil
end

return M
