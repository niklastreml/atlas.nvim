local M = {}

local controller = require("atlas.bitbucketv2.ui.controller")
local service = require("atlas.bitbucketv2.api.service")
local users = require("atlas.bitbucketv2.api.users")
local actions = require("atlas.bitbucketv2.actions")
local navigation = require("atlas.ui.navigation")
local footer = require("atlas.ui.components.footer")
local checkout = require("atlas.bitbucketv2.checkout")

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

	local repo_path = checkout.resolve_repo_path_for_pr(pr, { require_git = false, require_existing = false })

	---@type BitbucketActionContext
	local ctx = {
		pr = pr,
		source = "main",
		repo_path = repo_path,
	}

	actions.open(ctx, function(result, err)
		if err ~= nil then
			return
		end

		if result ~= nil and result.changed_pr then
			controller.refresh_pr(pr, function()
				-- Keep cursor position after refresh
			end)
		end
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
function M.refresh_pr(pr)
	if pr == nil then
		footer.notify("warn", "No PR selected")
		return
	end

	service.clear_pullrequest_memory_cache(pr)
	controller.refresh_pr(pr, function()
		local panel = require("atlas.ui.panel")
		if panel.is_open() then
			require("atlas.bitbucketv2.panel.init").on_select("pr", pr)
		end
	end)
end

function M.open_pr_search_popup()
	footer.notify("loading", "Loading workspaces...")
	users.fetch_workspaces(function(workspaces, err)
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

		local repositories = require("atlas.bitbucketv2.api.repositories")

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
				repositories.fetch_workspace_repositories(selected_ws.slug, input, function(repos, repo_err)
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
						controller.switch_view(search_view, function()
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
