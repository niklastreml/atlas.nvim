local M = {}

local actions = require("atlas.bitbucket.ui.main.controller")
local service = require("atlas.bitbucket.api.service")
local navigation = require("atlas.ui.navigation")
local footer = require("atlas.ui.components.footer")

---@param value string
---@param label string
local function copy_value(value, label)
	if value == "" then
		footer.notify("warn", "Bitbucket: Nothing to copy")
		return
	end

	vim.fn.setreg("+", value)
	vim.fn.setreg('"', value)
	footer.notify("info", string.format("Bitbucket: Copied %s", label))
end

---@param text any
---@return string
local function footer_text(text)
	return tostring(text or ""):gsub("[\r\n]+", " | ")
end

---@param pr BitbucketPR|nil
function M.open_pr_actions_popup(pr)
	if pr == nil then
		footer.notify("warn", "Bitbucket: No PR selected")
		return
	end

	local options = {
		{ id = "merge", label = "Merge" },
		{ id = "request_changes", label = "Request changes" },
		{ id = "approve", label = "Approve" },
	}

	vim.ui.select(options, {
		prompt = string.format("PR #%s action", tostring(pr.id or "")),
		format_item = function(item)
			return item.label
		end,
	}, function(choice)
		if choice == nil then
			return
		end
		footer.notify("info", string.format("Bitbucket: Starting %s for PR #%s", choice.label, tostring(pr.id or "")))

		local function on_done(_, err)
			if err ~= nil then
				footer.notify("error", string.format("Bitbucket: %s failed: %s", choice.label, footer_text(err)))
				return
			end
			footer.notify("success", string.format("Bitbucket: %s succeeded", choice.label))
			actions.refresh_current_view(function()
				navigation.focus_first_item()
			end)
		end

		if choice.id == "merge" then
			local merge_url = tostring((pr.links or {}).merge or "")
			if merge_url == "" then
				merge_url = tostring((((pr._raw or {}).links or {}).merge or {}).href or "")
			end
			service.merge_pullrequest(merge_url, {
				close_source_branch = true,
				merge_strategy = "merge_commit",
			}, on_done)
			return
		end

		if choice.id == "approve" then
			service.approve_pullrequest(tostring((pr.links or {}).approve or ""), on_done)
			return
		end

		if choice.id == "request_changes" then
			service.request_changes_pullrequest(tostring((pr.links or {}).request_changes or ""), on_done)
		end
	end)
end

---@param pr BitbucketPR|nil
function M.browse_current_pr(pr)
	if pr == nil then
		footer.notify("warn", "Bitbucket: No PR selected")
		return
	end

	local raw_html = (((pr._raw or {}).links or {}).html or {}).href
	if raw_html ~= nil and raw_html ~= "" then
		vim.ui.open(tostring(raw_html))
		return
	end

	local url = tostring((pr.links or {}).self or "")
	if url == "" then
		footer.notify("warn", "Bitbucket: No PR selected")
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
		footer.notify("warn", "Bitbucket: No PR selected")
		return
	end

	local panel = require("atlas.ui.panel")
	if panel.is_open() then
		require("atlas.bitbucket.ui.panel.controller").refresh_selected_pr()
		footer.notify("info", string.format("Bitbucket: Refetching PR #%s", tostring(pr.id or "")))
		return
	end
end

function M.open_pr_search_popup()
	footer.notify("info", "Bitbucket: Loading workspaces...")

	service.fetch_user_workspaces(function(workspaces, err)
		if err ~= nil then
			footer.notify("error", string.format("Bitbucket: Failed loading workspaces: %s", footer_text(err)))
			return
		end

		local ws = workspaces or {}
		if #ws == 0 then
			footer.notify("warn", "Bitbucket: No workspaces found")
			return
		end

		local function continue_with_workspace(selected_ws)
			if type(selected_ws) ~= "table" or tostring(selected_ws.slug or "") == "" then
				footer.notify("warn", "Bitbucket: Invalid workspace selection")
				return
			end

			vim.ui.input({ prompt = string.format("Search repos in %s: ", selected_ws.slug) }, function(input)
				if input == nil then
					return
				end

				footer.notify("info", "Bitbucket: Searching repositories...")
				service.fetch_workspace_repositories(selected_ws.slug, input, function(repos, repo_err)
					if repo_err ~= nil then
						footer.notify(
							"error",
							string.format("Bitbucket: Repo search failed: %s", footer_text(repo_err))
						)
						return
					end

					local list = repos or {}
					if #list == 0 then
						footer.notify("warn", "Bitbucket: No repositories found")
						return
					end

					vim.ui.select(list, {
						prompt = "Select repository",
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

						footer.notify("success", string.format("Bitbucket: Search view -> %s", repo.full_name))
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
