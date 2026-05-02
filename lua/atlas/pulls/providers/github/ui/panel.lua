---@class GitHubProviderPanel : PullsProviderPanel
local M = {}

local icons = require("atlas.ui.shared.icons")
local utils = require("atlas.ui.shared.utils")

local MAX_HASH_LEN = 12

---@param hex string
---@return string
local function label_hl(hex)
	local name = string.format("AtlasGHLabel_%s", hex)
	vim.api.nvim_set_hl(0, name, { fg = "#1e1e2e", bg = "#" .. hex, bold = true })
	return name
end

local merge_checks = {
	mergeable = nil, ---@type string|nil  "MERGEABLE"|"CONFLICTING"|"UNKNOWN"
	merge_state = nil, ---@type string|nil "CLEAN"|"DIRTY"|"BLOCKED"|"BEHIND"|"UNSTABLE"|"HAS_HOOKS"|"DRAFT"|"UNKNOWN"
	review_decision = nil, ---@type string|nil "APPROVED"|"CHANGES_REQUESTED"|"REVIEW_REQUIRED"|""
	loading = false,
}

local function reset_merge_checks()
	merge_checks.mergeable = nil
	merge_checks.merge_state = nil
	merge_checks.review_decision = nil
	merge_checks.loading = false
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

---@param builds PullsBuild[]
---@return string
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
-- Panel
--------------------------------------------------------------------------------

---@param pr PullRequest
---@return PullsPanelHeaderRow[]
function M.header_rows(pr)
	local raw = pr._raw or {}
	local rows = {}

	local review_decision = tostring(raw.reviewDecision or "")
	if review_decision ~= "" then
		local label = review_decision:gsub("_", " "):lower()
		label = label:sub(1, 1):upper() .. label:sub(2)
		local hl = "AtlasTextMuted"
		if review_decision == "APPROVED" then
			hl = "AtlasTextPositive"
		elseif review_decision == "CHANGES_REQUESTED" then
			hl = "AtlasTextWarning"
		end
		table.insert(rows, {
			k1 = "Review:",
			v1 = label,
			v1_hl = hl,
			k2 = "",
			v2 = "",
			v2_hl = "AtlasTextMuted",
		})
	end

	return rows
end

---@param pr PullRequest
---@return PullsPanelChip[]
function M.chips(pr)
	local chips = {}

	local hash = tostring(pr.source and pr.source.commit_hash or "")
	if hash ~= "" then
		if #hash > MAX_HASH_LEN then
			hash = hash:sub(1, MAX_HASH_LEN)
		end
		table.insert(chips, { label = hash, hl = "AtlasTabInactive" })
	end

	local raw = pr._raw or {}
	local label_nodes = type(raw.labels) == "table" and type(raw.labels.nodes) == "table" and raw.labels.nodes or {}
	for _, lbl in ipairs(label_nodes) do
		local name = tostring(lbl.name or "")
		if name ~= "" then
			local color = tostring(lbl.color or "")
			local hl = color ~= "" and label_hl(color) or "AtlasTabInactive"
			table.insert(chips, { label = name, hl = hl })
		end
	end

	local BUILD_HL = {
		successful = "AtlasTextPositive",
		failed = "AtlasLogError",
		inprogress = "AtlasTextWarning",
		stopped = "AtlasTextMuted",
	}

	local overview_state = require("atlas.pulls.ui.panel.pr.tabs.overview.state")
	local spinner = require("atlas.ui.components.spinner")
	if overview_state.builds == "loading" then
		table.insert(chips, { label = spinner.with_text("Loading checks"), hl = "AtlasTextMuted" })
	elseif type(overview_state.builds) == "table" and #overview_state.builds > 0 then
		local builds = overview_state.builds --[[@as PullsBuild[] ]]
		local status = aggregate_build_status(builds)
		if status ~= "unknown" then
			local icon = icons.pulls_status(status)
			local label = status:sub(1, 1):upper() .. status:sub(2)
			table.insert(chips, {
				label = string.format("%s %s", icon, label),
				hl = BUILD_HL[status] or "AtlasTextMuted",
			})
		end
	end

	return chips
end

---@type { cancel: fun() }[]
local panel_in_flight = {}

local function cancel_panel_fetches()
	for _, handle in ipairs(panel_in_flight) do
		handle.cancel()
	end
	panel_in_flight = {}
end

---@param handle { cancel: fun() }|nil
local function track_panel(handle)
	if handle then
		table.insert(panel_in_flight, handle)
	end
end

---@param pr PullRequest
---@param refresh fun()
function M.fetches(pr, refresh)
	cancel_panel_fetches()
	reset_merge_checks()

	local overview_state = require("atlas.pulls.ui.panel.pr.tabs.overview.state")
	local provider = require("atlas.pulls.state").provider
	local pullrequests = require("atlas.pulls.providers.github.api.pullrequests")

	overview_state.builds = "loading"
	if provider and type(provider.fetch_builds) == "function" then
		track_panel(provider.fetch_builds(pr, function(builds, err)
			overview_state.builds = err and err or (builds or {})
			refresh()
		end))
	end

	merge_checks.loading = true
	track_panel(pullrequests.get_merge_checks(pr, function(result, _)
		merge_checks.loading = false
		if result then
			merge_checks.mergeable = result.mergeable
			merge_checks.merge_state = result.merge_state
			merge_checks.review_decision = result.review_decision
		end
		refresh()
	end))
end

---@param pr PullRequest
---@param active_tab string|nil
---@return boolean
function M.is_loading(pr, active_tab) ---@diagnostic disable-line: unused-local
	local overview_state = require("atlas.pulls.ui.panel.pr.tabs.overview.state")
	local activity_state = require("atlas.pulls.ui.panel.pr.tabs.activity.state")
	local comments_state = require("atlas.pulls.ui.panel.pr.tabs.comments.state")
	local commits_state = require("atlas.pulls.ui.panel.pr.tabs.commits.state")
	local files_state = require("atlas.pulls.ui.panel.pr.tabs.files.state")
	if active_tab == "overview" then
		return overview_state.any_loading() or merge_checks.loading
	elseif active_tab == "activity" then
		return activity_state.any_loading()
	elseif active_tab == "comments" then
		return comments_state.any_loading()
	elseif active_tab == "commits" then
		return commits_state.any_loading()
	elseif active_tab == "files" then
		return files_state.any_loading()
	end
	return false
end

--------------------------------------------------------------------------------
-- Merge checks
--------------------------------------------------------------------------------

local PADDING_X = 1

local BUILD_STATE_ICON = {
	SUCCESSFUL = { icons.pulls_status("successful"), "AtlasTextPositive" },
	SUCCESS = { icons.pulls_status("successful"), "AtlasTextPositive" },
	FAILED = { icons.pulls_status("failed"), "AtlasLogError" },
	FAILURE = { icons.pulls_status("failed"), "AtlasLogError" },
	INPROGRESS = { icons.pulls_status("inprogress"), "AtlasTextWarning" },
	STOPPED = { icons.pulls_status("inprogress"), "AtlasTextMuted" },
}

---@param icon string
---@param icon_hl string
---@param label string
---@param details string[]|nil
---@param lines string[]
---@param spans table[]
local function push_section(icon, icon_hl, label, details, lines, spans)
	local line_text = string.format("%s %s", icon, label)
	table.insert(lines, string.rep(" ", PADDING_X) .. line_text)
	table.insert(spans, {
		line = #lines - 1,
		start_col = PADDING_X,
		end_col = PADDING_X + vim.api.nvim_strwidth(icon),
		hl_group = icon_hl,
	})
	for _, detail in ipairs(details or {}) do
		utils.push(lines, spans, "  " .. detail, "AtlasTextMuted", PADDING_X)
	end
end

---@class MergeCheckItem
---@field key string
---@field render fun(checks: table, builds: PullsBuild[]|string|nil, spinner: table): string|nil, string|nil, string|nil, string[]|nil

---@type MergeCheckItem[]
local MERGE_CHECK_ITEMS = {
	{
		key = "review",
		render = function(checks, _, spinner)
			local rd = checks.review_decision or ""
			if checks.loading then
				return icons.pulls_status("inprogress"),
					"AtlasTextMuted",
					"Reviews",
					{ spinner.with_text("Loading...") }
			elseif rd == "APPROVED" then
				return icons.pulls_status("successful"),
					"AtlasTextPositive",
					"Reviews",
					{ "All required reviewers have approved." }
			elseif rd == "CHANGES_REQUESTED" then
				return icons.pulls_status("failed"), "AtlasLogError", "Reviews", { "A reviewer has requested changes." }
			elseif rd == "REVIEW_REQUIRED" then
				return icons.pulls_status("inprogress"),
					"AtlasTextWarning",
					"Reviews",
					{ "At least one approving review is required." }
			else
				return icons.pulls_status("inprogress"), "AtlasTextMuted", "Reviews", { "No review required" }
			end
		end,
	},
	{
		key = "builds",
		render = function(_, builds, spinner)
			if builds == "loading" then
				return icons.pulls_status("inprogress"), "AtlasTextMuted", "Builds", { spinner.with_text("Loading...") }
			elseif type(builds) == "table" and #builds > 0 then
				local details = {}
				for _, build in ipairs(builds) do
					local s = tostring(build.state or ""):upper()
					local p = BUILD_STATE_ICON[s] or BUILD_STATE_ICON.STOPPED
					table.insert(details, string.format("%s %s", p[1], tostring(build.name or "")))
				end
				local overall = aggregate_build_status(builds)
				local pair = BUILD_STATE_ICON[overall:upper()] or BUILD_STATE_ICON.STOPPED
				return pair[1], pair[2], "Builds", details
			end
			return nil, nil, nil, nil
		end,
	},
	{
		key = "conflicts",
		render = function(checks, _, _)
			if checks.loading then
				return nil, nil, nil, nil
			end
			local m = checks.mergeable or ""
			if m == "MERGEABLE" then
				return icons.pulls_status("successful"),
					"AtlasTextPositive",
					"No conflicts with base branch",
					{ "Changes can be cleanly merged." }
			elseif m == "CONFLICTING" then
				return icons.pulls_status("failed"),
					"AtlasLogError",
					"This branch has conflicts that must be resolved",
					{ "Conflicting files must be resolved before merging." }
			end
			return nil, nil, nil, nil
		end,
	},
}

---@param pr PullRequest
---@param width integer
---@param lines string[]
---@param spans table[]
function M.overview_extra_sections(pr, width, lines, spans) ---@diagnostic disable-line: unused-local
	local overview_state = require("atlas.pulls.ui.panel.pr.tabs.overview.state")
	local spinner_mod = require("atlas.ui.components.spinner")
	local builds = overview_state.builds

	local has_merge_data = merge_checks.mergeable ~= nil or merge_checks.review_decision ~= nil
	if not has_merge_data and not merge_checks.loading and builds == nil then
		return
	end

	utils.push(lines, spans, "Merge Checks", "AtlasColumnHeader", PADDING_X)

	for _, item in ipairs(MERGE_CHECK_ITEMS) do
		local icon, icon_hl, label, details = item.render(merge_checks, builds, spinner_mod)
		if icon and icon_hl and label then
			push_section(icon, icon_hl, label, details, lines, spans)
		end
	end

	table.insert(lines, "")
end

--------------------------------------------------------------------------------
-- Tabs
--------------------------------------------------------------------------------

---@return PullsPanelTab[]
function M.tabs()
	return {
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
