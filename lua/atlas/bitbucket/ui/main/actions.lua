local M = {}

local actions = require("atlas.bitbucket.ui.main.controller")
local service = require("atlas.bitbucket.api.service")
local navigation = require("atlas.ui.navigation")
local footer = require("atlas.ui.components.footer")
local checkout = require("atlas.bitbucket.checkout")
local logger = require("atlas.core.logger")

---@param action_label string
---@param on_confirmed fun()
local function confirm_action(action_label, on_confirmed)
	vim.ui.input({
		prompt = string.format("Confirm %s? [y/N]: ", action_label),
	}, function(input)
		if input == nil then
			return
		end

		local normalized = vim.trim(tostring(input)):lower()
		if normalized ~= "y" and normalized ~= "yes" then
			footer.notify("info", "Action cancelled")
			return
		end

		on_confirmed()
	end)
end

---@param value string
---@param label string
local function copy_value(value, label)
	if value == "" then
		footer.notify("warn", "Nothing to copy")
		return
	end

	vim.fn.setreg("+", value)
	vim.fn.setreg('"', value)
	footer.notify("info", string.format("Copied %s", label))
end

---@param pr BitbucketPR|nil
function M.open_pr_actions_popup(pr)
	if pr == nil then
		footer.notify("warn", "No PR selected")
		return
	end

	local builtin = {
		{
			id = "checkout",
			label = "Checkout",
			confirmation = false,
			run = function()
				if pr == nil then
					footer.notify("warn", "No PR selected")
					return
				end

				local cfg = require("atlas.config").options.bitbucket or {}
				if vim.tbl_isempty(cfg.repo_paths or {}) then
					footer.notify("warn", "No repository paths configured for checkout")
					return
				end

				footer.notify("loading", string.format("Checking out PR #%s", tostring(pr.id or "")))
				checkout.checkout_pr(pr, function(success, err)
					vim.schedule(function()
						if err ~= nil then
							footer.notify("error", string.format("Checkout failed: %s", tostring(err)))
							return
						end

						footer.notify("success", string.format("Checked out PR #%s", tostring(pr.id or "")))
					end)
				end)
			end,
		},
		{
			id = "merge",
			label = "Merge",
			confirmation = true,
			run = function()
				local merge_url = tostring((pr.links or {}).merge or "")
				if merge_url == "" then
					merge_url = tostring((((pr._raw or {}).links or {}).merge or {}).href or "")
				end

				footer.notify("loading", "Starting Merge...")
				service.merge_pullrequest(merge_url, {
					close_source_branch = true,
					merge_strategy = "merge_commit",
				}, function(_, err)
					if err ~= nil then
						footer.notify("error", string.format("Merge failed: %s", tostring(err)))
						return
					end
					footer.notify("success", "Merge succeeded")
					actions.refresh_current_view(function()
						navigation.focus_first_item()
					end)
				end)
			end,
		},
		{
			id = "request_changes",
			label = "Request changes",
			confirmation = false,
			run = function()
				footer.notify("loading", "Starting Request changes...")
				service.request_changes_pullrequest(tostring((pr.links or {}).request_changes or ""), function(_, err)
					if err ~= nil then
						footer.notify("error", string.format("Request changes failed: %s", tostring(err)))
						return
					end
					footer.notify("success", "Request changes succeeded")
					actions.refresh_current_view(function()
						navigation.focus_first_item()
					end)
				end)
			end,
		},
		{
			id = "approve",
			label = "Approve",
			confirmation = false,
			run = function()
				footer.notify("loading", "Starting Approve...")
				service.approve_pullrequest(tostring((pr.links or {}).approve or ""), function(_, err)
					if err ~= nil then
						footer.notify("error", string.format("Approve failed: %s", tostring(err)))
						return
					end
					footer.notify("success", "Approve succeeded")
					actions.refresh_current_view(function()
						navigation.focus_first_item()
					end)
				end)
			end,
		},
	}

	local cfg = require("atlas.config").options.bitbucket or {}
	local custom_actions = cfg.custom_actions or {}
	local repo_path = checkout.resolve_repo_path_for_pr(pr, { require_git = false, require_existing = false })
	local ctx = {
		repo_path = repo_path,
		pr = pr,
	}

	local options = {}
	for _, item in ipairs(builtin) do
		table.insert(options, item)
	end

	for _, item in ipairs(custom_actions) do
		if type(item) == "table" and type(item.label) == "string" and type(item.run) == "function" then
			table.insert(options, {
				id = tostring(item.id or item.label),
				label = item.label,
				confirmation = item.confirmation == true,
				run = function()
					footer.notify("loading", string.format("Running %s...", tostring(item.label)))

					local done_called = false
					local function done(ok, message)
						if done_called then
							return
						end
						done_called = true

						vim.schedule(function()
							if ok == false then
								footer.notify("error", tostring(message or (item.label .. " failed")))
								logger.logerror(string.format("Custom action failed: %s", tostring(message)))
								return
							end
							footer.notify("success", tostring(message or (item.label .. " done")))
						end)
					end

					local ok, err = pcall(item.run, pr, ctx, done)
					if not ok then
						--- in case the call crashes, call done ourself
						done(false, string.format("Custom action failed: %s", tostring(err)))
						logger.logerror(
							string.format("Custom action '%s' execution error: %s", item.label, tostring(err))
						)
					end
				end,
			})
		end
	end

	vim.ui.select(options, {
		prompt = string.format("PR #%s action", tostring(pr.id or "")),
		kind = "atlas_bitbucket_pr_actions",
		format_item = function(item)
			return item.label
		end,
	}, function(choice)
		if choice == nil then
			return
		end

		if choice.confirmation == true then
			confirm_action(choice.label, choice.run)
			return
		end

		choice.run()
	end)
end

---@param pr BitbucketPR|nil
function M.browse_current_pr(pr)
	if pr == nil then
		footer.notify("warn", "No PR selected")
		return
	end

	local raw_html = (((pr._raw or {}).links or {}).html or {}).href
	if raw_html ~= nil and raw_html ~= "" then
		vim.ui.open(tostring(raw_html))
		return
	end

	local url = tostring((pr.links or {}).self or "")
	if url == "" then
		footer.notify("warn", "No PR selected")
		return
	end

	vim.ui.open(url)
end

---@param pr BitbucketPR|nil
function M.copy_current_pr_id(pr)
	local id = pr and tostring(pr.id or "") or ""
	copy_value(id, "PR id")
end

---@param pr BitbucketPR|nil
function M.copy_current_pr_url(pr)
	if pr == nil then
		return
	end

	local raw_html = (((pr._raw or {}).links or {}).html or {}).href
	if raw_html ~= nil and raw_html ~= "" then
		copy_value(tostring(raw_html), "PR URL")
		return
	end

	local url = tostring((pr.links or {}).self or "")
	copy_value(url, "PR URL")
end

---@param pr BitbucketPR|nil
function M.refresh_selected_pr_cache(pr)
	if pr == nil then
		footer.notify("warn", "No PR selected")
		return
	end

	local panel = require("atlas.ui.panel")
	if panel.is_open() then
		require("atlas.bitbucket.ui.panel.prs.controller").refresh_selected_pr()
		footer.notify("info", string.format("Refetching PR #%s", tostring(pr.id or "")))
		return
	end
end

function M.open_pr_search_popup()
	footer.notify("loading", "Loading workspaces...")

	service.fetch_user_workspaces(function(workspaces, err)
		if err ~= nil then
			footer.notify("error", string.format("Failed loading workspaces: %s", tostring(err)))
			return
		end

		local ws = workspaces or {}
		if #ws == 0 then
			footer.notify("warn", "No workspaces found")
			return
		end

		footer.notify("info", string.format("Loaded %d workspaces", #ws), 1200)

		local function continue_with_workspace(selected_ws)
			if type(selected_ws) ~= "table" or tostring(selected_ws.slug or "") == "" then
				footer.notify("warn", "Invalid workspace selection")
				return
			end

			vim.ui.input({ prompt = string.format("Search repos in %s: ", selected_ws.slug) }, function(input)
				if input == nil then
					return
				end

				footer.notify("loading", "Searching repositories...")
				service.fetch_workspace_repositories(selected_ws.slug, input, function(repos, repo_err)
					if repo_err ~= nil then
						footer.notify("error", string.format("Repo search failed: %s", tostring(repo_err)))
						return
					end

					local list = repos or {}
					if #list == 0 then
						footer.notify("warn", "No repositories found")
						return
					end

					footer.notify("info", string.format("Found %d repositories", #list), 1200)

					vim.ui.select(list, {
						prompt = "Select repository",
						kind = "atlas_bitbucket_repo_select",
						format_item = function(item)
							return item.full_name ~= "" and item.full_name or item.name
						end,
					}, function(repo)
						if repo == nil then
							return
						end

						--- Create a temporary view to add the repo
						local search_view = {
							name = "Search",
							key = nil,
							repos = {
								{
									workspace = repo.workspace,
									repo = repo.slug,
								},
							},
						}

						footer.notify("success", string.format("Search view -> %s", repo.full_name))
						actions.switch_view(search_view, function()
							navigation.focus_first_item()
						end)
					end)
				end)
			end)
		end

		if #ws == 1 then
			continue_with_workspace(ws[1])
			return
		end

		vim.ui.select(ws, {
			prompt = "Select workspace",
			kind = "atlas_bitbucket_workspace_select",
			format_item = function(item)
				return item.slug
			end,
		}, function(selected)
			if selected == nil then
				return
			end
			continue_with_workspace(selected)
		end)
	end)
end

return M
