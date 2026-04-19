---@class MockProviderPanel : PullsProviderPanel
local M = {}

local icons = require("atlas.ui.shared.icons")

local BUILD_HL = {
	successful = "AtlasTextPositive",
	failed = "AtlasLogError",
	inprogress = "AtlasTextWarning",
	stopped = "AtlasTextMuted",
}

local MAX_HASH_LEN = 12

---@param builds PullsBuild[]
---@return string status
local function aggregate_build_status(builds)
	local has_success = false
	local has_stopped = false
	for _, b in ipairs(builds) do
		local s = tostring(b.state or ""):upper()
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

--------------------------------------------------------------------------------
-- Panel interface
--------------------------------------------------------------------------------

---@param pr PullRequest
---@return PullsPanelHeaderRow[]
function M.header_rows(pr)
	return {
		{
			k1 = "Close source:",
			v1 = pr.close_source_branch and "yes" or "no",
			v1_hl = pr.close_source_branch and "AtlasTextPositive" or "AtlasLogError",
			k2 = "",
			v2 = "",
			v2_hl = "AtlasTextMuted",
		},
	}
end

---@param pr PullRequest
---@return PullsPanelChip[]
function M.chips(pr)
	local chips = {}
	local overview_state = require("atlas.pulls.ui.panel.pr.tabs.overview.state")

	-- Commit hash
	local hash = tostring(pr.source and pr.source.commit_hash or "")
	if hash ~= "" then
		if #hash > MAX_HASH_LEN then
			hash = hash:sub(1, MAX_HASH_LEN)
		end
		table.insert(chips, { label = hash, hl = "AtlasTabInactive" })
	end

	-- Aggregated build status
	local spinner = require("atlas.ui.components.spinner")
	if overview_state.builds == "loading" then
		table.insert(chips, { label = spinner.with_text("Loading builds"), hl = "AtlasTextMuted" })
	elseif type(overview_state.builds) == "table" and #overview_state.builds > 0 then
		local status = aggregate_build_status(overview_state.builds)
		if status ~= "unknown" then
			local icon = icons.pulls_status(status)
			local label = status:sub(1, 1):upper() .. status:sub(2)
			table.insert(
				chips,
				{ label = string.format("%s %s", icon, label), hl = BUILD_HL[status] or "AtlasTextMuted" }
			)
		end
	end

	return chips
end

---@param pr PullRequest
---@param done fun()
function M.fetches(pr, done) end

---@param pr PullRequest
---@return boolean
function M.is_loading(pr)
	local overview_state = require("atlas.pulls.ui.panel.pr.tabs.overview.state")
	local activity_state = require("atlas.pulls.ui.panel.pr.tabs.activity.state")
	local comments_state = require("atlas.pulls.ui.panel.pr.tabs.comments.state")
	local commits_state = require("atlas.pulls.ui.panel.pr.tabs.commits.state")
	local files_state = require("atlas.pulls.ui.panel.pr.tabs.files.state")
	return overview_state.any_loading()
		or activity_state.any_loading()
		or comments_state.any_loading()
		or commits_state.any_loading()
		or files_state.any_loading()
end

---@return PullsPanelTab[]
function M.tabs()
	return {
		{
			key = "mock",
			label = "Mock",
			icon = icons.pulls_provider("mock", "provider"),
			mod = require("atlas.pulls.providers.mock.ui.tabs.mock"),
		},
		{
			key = "overview",
			label = "Overview",
			icon = icons.general("overview"),
			mod = require("atlas.pulls.ui.panel.pr.tabs.overview"),
		},
		{
			key = "activity",
			label = "Activity",
			icon = icons.pulls("activity"),
			mod = require("atlas.pulls.ui.panel.pr.tabs.activity"),
		},
		{
			key = "comments",
			label = "Comments",
			icon = icons.general("comment"),
			mod = require("atlas.pulls.ui.panel.pr.tabs.comments"),
		},
		{
			key = "commits",
			label = "Commits",
			icon = icons.pulls("commit"),
			mod = require("atlas.pulls.ui.panel.pr.tabs.commits"),
		},
		{
			key = "files",
			label = "Changes",
			icon = icons.pulls("files"),
			mod = require("atlas.pulls.ui.panel.pr.tabs.files"),
		},
	}
end

return M
