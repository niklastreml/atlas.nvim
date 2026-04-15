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
