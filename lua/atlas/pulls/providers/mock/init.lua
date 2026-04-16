local icons = require("atlas.shared.icons")

local SCRIPT_DIR = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")

---@param filename string
---@return table
local function load_json(filename)
	local path = SCRIPT_DIR .. "/data/" .. filename
	local file = io.open(path, "r")
	if not file then
		error("mock: cannot open " .. path)
	end
	local content = file:read("*a")
	file:close()
	return vim.json.decode(content)
end

---@param repo_slug string
---@param pr_num string|number
---@return PullsLink
local function build_link(repo_slug, pr_num)
	return {
		html = "https://github.com/emrearmagan/atlas.nvim/tree/main",
	}
end

---@param groups PullsGroup[]
local function hydrate(groups)
	for _, group in ipairs(groups) do
		for _, pr in ipairs(group.prs) do
			pr.link = build_link(pr.repo_name, pr.id)
			pr._raw = nil
		end
	end
end

local MOCK_GROUPS = load_json("pullrequests.json")
hydrate(MOCK_GROUPS)

---@param repo_id string
---@param pr_id string|number
---@return PullRequest|nil
local function find_pr(repo_id, pr_id)
	for _, group in ipairs(MOCK_GROUPS) do
		if group.repo.id == repo_id then
			for _, pr in ipairs(group.prs) do
				if tostring(pr.id) == tostring(pr_id) then
					return pr
				end
			end
		end
	end
	return nil
end

---@class MockPullsProvider : PullsProvider
local M = {
	id = "mock",
	name = "Mock",
	icon = icons.pulls_provider("mock", "provider"),
	hl_group = "AtlasMockTheme",
}

function M.setup()
	require("atlas.pulls.providers.mock.highlights").setup()
end

---@param on_done fun(user: PullsUser|nil, err: string|nil)
function M.fetch_user(on_done)
	vim.defer_fn(function()
		on_done({
			name = "Mock User",
			id = "mock-user-1",
			username = "mockuser",
		}, nil)
	end, 200)
end

---@param view PullsView
---@param opts table
---@param on_done fun(groups: PullsGroup[], err: string[]|nil)
---@return { cancel: fun() }|nil
function M.fetch_pullrequests(view, opts, on_done)
	local cancelled = false
	vim.defer_fn(function()
		if cancelled then
			return
		end
		on_done(MOCK_GROUPS, nil)
	end, 800)
	return {
		cancel = function()
			cancelled = true
		end,
	}
end

---@param repo_id string
---@param pr_id string|number
---@param opts table
---@param on_done fun(pr: PullRequest|nil, err: string|nil)
---@return { cancel: fun() }|nil
function M.fetch_pullrequest(repo_id, pr_id, opts, on_done)
	local cancelled = false
	vim.defer_fn(function()
		if cancelled then
			return
		end
		local pr = find_pr(repo_id, pr_id)
		if pr then
			on_done(vim.deepcopy(pr), nil)
		else
			on_done(nil, "PR not found")
		end
	end, 500)
	return {
		cancel = function()
			cancelled = true
		end,
	}
end

---@return PullsView[]
function M.views()
	return {
		{ name = "Compact", key = "1", provider_id = "mock", layout = "compact", provider_view = {} },
		{ name = "Plain", key = "2", provider_id = "mock", layout = "plain", provider_view = {} },
	}
end

---@param pr PullRequest
---@param on_done fun(ok: boolean)
function M.open_diff(pr, on_done)
	local footer = require("atlas.ui.components.footer")
	footer.notify("info", "Diff view not available for mock provider")
	on_done(false)
end

---@param pr PullRequest
---@param on_done fun(ok: boolean)
function M.checkout(pr, on_done)
	local footer = require("atlas.ui.components.footer")
	footer.notify("info", "Checkout not available for mock provider")
	on_done(false)
end

---@param pr PullRequest
---@return PullsPanelHeaderRow[]
function M.panel_header_rows(pr)
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

local BUILD_STATUSES = { "SUCCESSFUL", "FAILED", "INPROGRESS", "STOPPED" }
local BUILD_NAMES = { "ci/build", "ci/lint", "ci/test", "deploy/staging" }

local FAKE_REVIEWERS = {
	{ name = "Alice", nickname = "alice", decision = "approved" },
	{ name = "Bob", nickname = "bob", decision = "changes_requested" },
	{ name = "Charlie", nickname = "charlie", decision = "pending" },
	{ name = "Diana", nickname = "diana", decision = "approved" },
	{ name = "Eve", nickname = "eve", decision = "pending" },
}

local FAKE_DIFFSTAT = {
	{ status = "modified", path = "lua/atlas/pulls/ui/panel/init.lua", lines_added = 42, lines_removed = 18 },
	{ status = "added", path = "lua/atlas/pulls/ui/panel/tabs/overview/init.lua", lines_added = 120, lines_removed = 0 },
	{ status = "removed", path = "lua/atlas/pulls/old_panel.lua", lines_added = 0, lines_removed = 85 },
	{ status = "renamed", path = "lua/atlas/pulls/state.lua", old_path = "lua/atlas/pulls/old_state.lua", lines_added = 3, lines_removed = 1 },
	{ status = "modified", path = "lua/atlas/shared/utils.lua", lines_added = 15, lines_removed = 2 },
}

local BUILD_HL = {
	successful = "AtlasTextPositive",
	failed = "AtlasLogError",
	inprogress = "AtlasTextWarning",
	stopped = "AtlasTextMuted",
}

--------------------------------------------------------------------------------
-- Panel data fetches
--------------------------------------------------------------------------------

---@param pr PullRequest
---@param on_done fun(reviewers: PullsReviewer[]|nil, err: string|nil)
---@return { cancel: fun() }|nil
function M.fetch_reviewers(pr, on_done)
	local cancelled = false
	vim.defer_fn(function()
		if cancelled then
			return
		end
		local count = 2 + math.random(3)
		local result = {}
		for i = 1, math.min(count, #FAKE_REVIEWERS) do
			table.insert(result, FAKE_REVIEWERS[i])
		end
		on_done(result, nil)
	end, 600 + math.random(800))
	return { cancel = function() cancelled = true end }
end

---@param pr PullRequest
---@param on_done fun(builds: PullsBuild[]|nil, err: string|nil)
---@return { cancel: fun() }|nil
function M.fetch_builds(pr, on_done)
	local cancelled = false
	vim.defer_fn(function()
		if cancelled then
			return
		end
		local entries = {}
		local count = 1 + math.random(3)
		for i = 1, count do
			table.insert(entries, {
				name = BUILD_NAMES[((i - 1) % #BUILD_NAMES) + 1],
				state = BUILD_STATUSES[math.random(#BUILD_STATUSES)],
				key = "build-" .. i,
				url = "https://example.com/build/" .. i,
			})
		end
		on_done(entries, nil)
	end, 800 + math.random(600))
	return { cancel = function() cancelled = true end }
end

---@param pr PullRequest
---@param on_done fun(entries: PullsDiffstatEntry[]|nil, err: string|nil)
---@return { cancel: fun() }|nil
function M.fetch_diffstat(pr, on_done)
	local cancelled = false
	vim.defer_fn(function()
		if cancelled then
			return
		end
		local count = 2 + math.random(#FAKE_DIFFSTAT - 1)
		local result = {}
		for i = 1, math.min(count, #FAKE_DIFFSTAT) do
			result[i] = FAKE_DIFFSTAT[i]
		end
		on_done(result, nil)
	end, 500 + math.random(700))
	return { cancel = function() cancelled = true end }
end

---@param pr PullRequest
---@param done fun()
function M.panel_fetches(pr, done)
	-- Provider-level fetches (non-tab). Currently none for mock.
end

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

---@param pr PullRequest
---@return PullsPanelChip[]
function M.panel_chips(pr)
	local chips = {}
	local overview_state = require("atlas.pulls.ui.panel.tabs.overview.state")

	-- Commit hash
	local hash = tostring(pr.source and pr.source.commit_hash or "")
	if hash ~= "" then
		if #hash > MAX_HASH_LEN then
			hash = hash:sub(1, MAX_HASH_LEN)
		end
		table.insert(chips, { label = hash, hl = "AtlasTabInactive" })
	end

	-- Aggregated build status
	local s = require("atlas.ui.components.spinner")
	if overview_state.builds == "loading" then
		table.insert(chips, { label = s.with_text("Loading builds"), hl = "AtlasTextMuted" })
	elseif type(overview_state.builds) == "table" and #overview_state.builds > 0 then
		local status = aggregate_build_status(overview_state.builds)
		if status ~= "unknown" then
			local icon = icons.pulls_status(status)
			local label = status:sub(1, 1):upper() .. status:sub(2)
			table.insert(chips, { label = string.format("%s %s", icon, label), hl = BUILD_HL[status] or "AtlasTextMuted" })
		end
	end

	return chips
end

---@param pr PullRequest
---@return boolean
function M.panel_is_loading(pr)
	local overview_state = require("atlas.pulls.ui.panel.tabs.overview.state")
	if overview_state.any_loading() then
		return true
	end

	return false
end

---@return PullsPanelTab[]
function M.panel_tabs()
	return {
		{ key = "overview", label = "Overview", icon = icons.general("overview"), mod = require("atlas.pulls.ui.panel.tabs.overview") },
		{ key = "mock", label = "Mock", icon = icons.pulls_provider("mock", "provider"), mod = require("atlas.pulls.providers.mock.tabs.mock") },
		{ key = "activity", label = "Activity", icon = icons.general("updated"), mod = require("atlas.pulls.ui.panel.tabs.overview") },
		{ key = "comments", label = "Comments", icon = icons.general("comment"), mod = require("atlas.pulls.ui.panel.tabs.overview") },
	}
end

---@param pr PullRequest|nil
---@param opts table
---@param on_done fun(result: PullsActionResult|nil)
function M.open_actions(pr, opts, on_done)
	local footer = require("atlas.ui.components.footer")

	---@type { id: string, label: string, run: fun(done: fun(result: PullsActionResult|nil)) }[]
	local actions = {
		{
			id = "approve",
			label = "Approve",
			run = function(done)
				footer.notify("loading", "Approving PR...")
				vim.defer_fn(function()
					footer.notify("success", "PR approved", 1200)
					done({ changed_pr = true, message = "Approved" })
				end, 300)
			end,
		},
		{
			id = "merge",
			label = "Merge",
			run = function(done)
				vim.ui.input({
					prompt = string.format("Confirm merge PR #%s? [y/N]: ", tostring(pr.id or "")),
				}, function(input)
					if input == nil then
						done({ changed_pr = false, message = "Merge cancelled" })
						return
					end

					local normalized = vim.trim(tostring(input)):lower()
					if normalized ~= "y" and normalized ~= "yes" then
						footer.notify("info", "Merge cancelled")
						done({ changed_pr = false, message = "Merge cancelled" })
						return
					end

					footer.notify("loading", "Merging PR...")
					vim.defer_fn(function()
						footer.notify("success", "Merge succeeded", 1200)
						done({ changed_pr = true, message = "Merged" })
					end, 500)
				end)
			end,
		},
		{
			id = "decline",
			label = "Decline",
			run = function(done)
				vim.ui.input({
					prompt = string.format("Confirm decline PR #%s? [y/N]: ", tostring(pr.id or "")),
				}, function(input)
					if input == nil then
						done({ changed_pr = false, message = "Decline cancelled" })
						return
					end

					local normalized = vim.trim(tostring(input)):lower()
					if normalized ~= "y" and normalized ~= "yes" then
						footer.notify("info", "Decline cancelled")
						done({ changed_pr = false, message = "Decline cancelled" })
						return
					end

					footer.notify("loading", "Declining PR...")
					vim.defer_fn(function()
						footer.notify("success", "PR declined", 1200)
						done({ changed_pr = true, message = "Declined" })
					end, 300)
				end)
			end,
		},
		{
			id = "request_changes",
			label = "Request changes",
			run = function(done)
				footer.notify("loading", "Requesting changes...")
				vim.defer_fn(function()
					footer.notify("success", "Changes requested", 1200)
					done({ changed_pr = true, message = "Changes requested" })
				end, 300)
			end,
		},
	}

	vim.ui.select(actions, {
		prompt = string.format("Choose action for PR #%s", tostring(pr.id or "")),
		format_item = function(action)
			return action.label
		end,
	}, function(action)
		if action == nil then
			on_done({ changed_pr = false, message = "Action cancelled" })
			return
		end

		action.run(on_done)
	end)
end

return M
